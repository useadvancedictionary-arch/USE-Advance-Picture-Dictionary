using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Windows.Graphics.Imaging;
using Windows.Media.Ocr;
using Windows.Storage;

namespace CardOcrTool;

public class CardOcrEntry
{
    public int index { get; set; }
    public int row { get; set; }
    public int column { get; set; }
    public string title { get; set; } = "";
    public string meaning { get; set; } = "";
    public string allText { get; set; } = "";
}

public class CardOcrResult
{
    public int imageWidth { get; set; }
    public int imageHeight { get; set; }
    public int rows { get; set; }
    public int columns { get; set; }
    public List<CardOcrEntry> cards { get; set; } = new();
}

public class WordBox
{
    public string Text { get; set; } = "";
    public double X { get; set; }
    public double Y { get; set; }
    public double Width { get; set; }
    public double Height { get; set; }
    public double MidX => X + (Width / 2.0);
    public double MidY => Y + (Height / 2.0);
}

public class Program
{
    public static async Task<int> Main(string[] args)
    {
        if (args.Length == 0) return 1;

        string imagePath = Path.GetFullPath(args[0]);
        if (!File.Exists(imagePath)) return 2;

        int rows = args.Length > 1 && int.TryParse(args[1], out int r) ? r : 2;
        int cols = args.Length > 2 && int.TryParse(args[2], out int c) ? c : 5;

        var file = await StorageFile.GetFileFromPathAsync(imagePath);
        using var stream = await file.OpenAsync(FileAccessMode.Read);
        var decoder = await BitmapDecoder.CreateAsync(stream);
        using var bitmap = await decoder.GetSoftwareBitmapAsync();

        int imgW = (int)bitmap.PixelWidth;
        int imgH = (int)bitmap.PixelHeight;

        var engine = OcrEngine.TryCreateFromUserProfileLanguages() ?? OcrEngine.TryCreateFromLanguage(new Windows.Globalization.Language("en-US"));
        if (engine == null) return 3;

        var ocr = await engine.RecognizeAsync(bitmap);

        var allWords = new List<WordBox>();
        foreach (var line in ocr.Lines)
        {
            foreach (var w in line.Words)
            {
                allWords.Add(new WordBox
                {
                    Text = w.Text,
                    X = w.BoundingRect.X,
                    Y = w.BoundingRect.Y,
                    Width = w.BoundingRect.Width,
                    Height = w.BoundingRect.Height
                });
            }
        }

        var result = new CardOcrResult
        {
            imageWidth = imgW,
            imageHeight = imgH,
            rows = rows,
            columns = cols
        };

        double rowH = (double)imgH / rows;

        for (int rIdx = 0; rIdx < rows; rIdx++)
        {
            double rY1 = rIdx * rowH;
            double rY2 = (rIdx + 1) * rowH;
            double headerY2 = rY1 + (rowH * 0.35); // Title is in top 35% of each row

            // Get all header words in this row
            var headerWords = allWords
                .Where(w => w.MidY >= rY1 && w.MidY <= headerY2)
                .Where(w => !w.Text.StartsWith("Meaning", StringComparison.OrdinalIgnoreCase))
                .Where(w => !(w.Text.Length == 1 && char.IsDigit(w.Text[0]))) // skip stray digits
                .OrderBy(w => w.X)
                .ToList();

            // Cluster header words into columns by gap threshold
            // In a 5-column grid across ~1500px, column spacing is ~300px, gap between cards is >= 40px
            var columnClusters = new List<List<WordBox>>();
            List<WordBox> currentCluster = new();

            double cardNominalWidth = (double)imgW / cols;

            foreach (var w in headerWords)
            {
                if (currentCluster.Count == 0)
                {
                    currentCluster.Add(w);
                }
                else
                {
                    var prev = currentCluster.Last();
                    double gap = w.X - (prev.X + prev.Width);
                    double span = w.X - currentCluster.First().X;

                    // If gap > 35px or cluster span exceeds card nominal width, start new cluster
                    if (gap > 35.0 || span > (cardNominalWidth * 0.95))
                    {
                        columnClusters.Add(currentCluster);
                        currentCluster = new List<WordBox> { w };
                    }
                    else
                    {
                        currentCluster.Add(w);
                    }
                }
            }
            if (currentCluster.Count > 0)
            {
                columnClusters.Add(currentCluster);
            }

            // Map clusters to the 5 columns based on average X
            for (int cIdx = 0; cIdx < cols; cIdx++)
            {
                int cardIndex = rIdx * cols + cIdx;
                double colCenterX = (cIdx + 0.5) * cardNominalWidth;

                // Find cluster closest to this column center
                var matchingCluster = columnClusters
                    .OrderBy(cl => Math.Abs(cl.Average(w => w.MidX) - colCenterX))
                    .FirstOrDefault(cl => Math.Abs(cl.Average(w => w.MidX) - colCenterX) < (cardNominalWidth * 0.6));

                string title = "";
                if (matchingCluster != null)
                {
                    var lines = new List<List<WordBox>>();
                    foreach (var w in matchingCluster.OrderBy(w => w.Y))
                    {
                        var target = lines.FirstOrDefault(l => Math.Abs(l.Average(item => item.Y) - w.Y) < 22.0);
                        if (target != null) target.Add(w);
                        else lines.Add(new List<WordBox> { w });
                    }
                    var sortedWords = lines
                        .OrderBy(l => l.Average(item => item.Y))
                        .SelectMany(l => l.OrderBy(item => item.X).Select(item => item.Text));

                    title = string.Join(" ", sortedWords).Trim();
                }

                // Meaning in bottom of card
                double cX1 = cIdx * cardNominalWidth;
                double cX2 = (cIdx + 1) * cardNominalWidth;
                double meaningY1 = rY1 + (rowH * 0.55);

                var meaningWords = allWords
                    .Where(w => w.MidX >= cX1 && w.MidX < cX2 && w.MidY >= meaningY1 && w.MidY <= rY2)
                    .Where(w => !w.Text.StartsWith("Meaning", StringComparison.OrdinalIgnoreCase))
                    .OrderBy(w => Math.Round(w.Y / 12.0))
                    .ThenBy(w => w.X)
                    .Select(w => w.Text);

                string meaning = string.Join(" ", meaningWords).Trim();

                result.cards.Add(new CardOcrEntry
                {
                    index = cardIndex,
                    row = rIdx,
                    column = cIdx,
                    title = title,
                    meaning = meaning
                });
            }
        }

        string json = JsonSerializer.Serialize(result, new JsonSerializerOptions { WriteIndented = true });
        Console.WriteLine(json);
        return 0;
    }
}
