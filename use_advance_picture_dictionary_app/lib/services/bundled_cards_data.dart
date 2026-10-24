import '../models/picture_word_entry.dart';

/// Pre-bundled reference cards cropped from high-definition flashcard sheets
/// Data sourced directly from USE Advance Pictue Dictionary.xlsx (15916 entries)
class BundledCardsData {
  static const Map<String, String> wordToAssetMap = {
    'a bad workman always quarrels with his tools': 'assets/cards/a_bad_workman_always_quarrels_with_his_tools.jpg',
    'a ballpark figure': 'assets/cards/a_ballpark_figure.jpg',
    'a bird\'s eye view': 'assets/cards/a_birds_eye_view.jpg',
    'a birds eye view': 'assets/cards/a_birds_eye_view.jpg',
    'a bird’s eye view': 'assets/cards/a_birds_eye_view.jpg',
    'a blessing in disguise': 'assets/cards/a_blessing_in_disguise.jpg',
    'a blur question': 'assets/cards/a_blur_question.jpg',
    'a chink in someone\'s armour': 'assets/cards/a_chink_in_someones_armour.jpg',
    'a chink in someones armour': 'assets/cards/a_chink_in_someones_armour.jpg',
    'a chink in someone’s armour': 'assets/cards/a_chink_in_someones_armour.jpg',
    'a cog in the machine': 'assets/cards/a_cog_in_the_machine.jpg',
    'a dark horse': 'assets/cards/a_dark_horse.jpg',
    'a dog in manger': 'assets/cards/a_dog_in_manger.jpg',
    'a friend in need is a friend in indeed': 'assets/cards/a_friend_in_need_is_a_friend_indeed.jpg',
    'a friend in need is a friend indeed': 'assets/cards/a_friend_in_need_is_a_friend_indeed.jpg',
    'a going concern': 'assets/cards/a_going_concern.jpg',
    'a happy medium': 'assets/cards/a_happy_medium.jpg',
    'a hard nut to crack': 'assets/cards/a_hard_nut_to_crack.jpg',
    'a hard nut to cut': 'assets/cards/a_hard_nut_to_cut.jpg',
    'a leopard does not change its spots': 'assets/cards/a_leopard_does_not_change_its_spots.jpg',
    'a part of furniture': 'assets/cards/a_part_of_furniture.jpg',
    'a passport to': 'assets/cards/a_passport_to.jpg',
    'a penny for your thoughts': 'assets/cards/a_penny_for_your_thoughts.jpg',
    'a picture is worth 1000 words': 'assets/cards/a_picture_is_worth_1000_words.jpg',
    'a picture is worth a thousand words': 'assets/cards/a_picture_is_worth_1000_words.jpg',
    'a wet blanket': 'assets/cards/a_wet_blanket.jpg',
    'a wild goose chase': 'assets/cards/a_wild_goose_chase.jpg',
    'a wolf in sheep\'s clothing': 'assets/cards/a_wolf_in_sheeps_clothing.jpg',
    'a wolf in sheeps clothing': 'assets/cards/a_wolf_in_sheeps_clothing.jpg',
    'a wolf in sheep’s clothing': 'assets/cards/a_wolf_in_sheeps_clothing.jpg',
    'abandon': 'assets/cards/abandon.jpg',
    'abase': 'assets/cards/abase.jpg',
    'abash': 'assets/cards/abash.jpg',
    'abate': 'assets/cards/abate.jpg',
    'abatement': 'assets/cards/abatement.jpg',
    'abbey': 'assets/cards/abbey.jpg',
    'abbot': 'assets/cards/abbot.jpg',
    'abdicate': 'assets/cards/abdicate.jpg',
    'abdom': 'assets/cards/abdom.jpg',
    'abdominal': 'assets/cards/abdominal.jpg',
    'abduct': 'assets/cards/abduct.jpg',
    'aberrant': 'assets/cards/aberrant.jpg',
    'aberration': 'assets/cards/aberration.jpg',
    'abet': 'assets/cards/abet.jpg',
    'abey': 'assets/cards/abey.jpg',
    'abeyance': 'assets/cards/abeyance.jpg',
    'abeyancy': 'assets/cards/abeyancy.jpg',
    'abhor': 'assets/cards/abhor.jpg',
    'abject': 'assets/cards/abject.jpg',
    'abjugate': 'assets/cards/abjugate.jpg',
    'abjure': 'assets/cards/abjure.jpg',
    'ablution': 'assets/cards/ablution.jpg',
    'abnegate': 'assets/cards/abnegate.jpg',
    'abode': 'assets/cards/abode.jpg',
    'abolish': 'assets/cards/abolish.jpg',
    'abolition': 'assets/cards/abolition.jpg',
    'abort': 'assets/cards/abort.jpg',
    'wild goose chase': 'assets/cards/a_wild_goose_chase.jpg',
    'wolf in sheep\'s clothing': 'assets/cards/a_wolf_in_sheeps_clothing.jpg',
  };

  static List<PictureWordEntry> getStarterEntries() {
    return const [
      PictureWordEntry(
        word: 'A bad workman always quarrels with his tools',
        partOfSpeech: 'Proverb',
        englishMeaning: 'An incompetent person always blames his tools or external factors instead of accepting his own lack of skill. Skilled people can work well even with poor resources, but unskilled people always find excuses.',
        synonyms: ['Excuse-maker'],
        antonyms: ['Skilled person'],
        imageUrl: 'assets/cards/a_bad_workman_always_quarrels_with_his_tools.jpg',
        thumbnailUrl: 'assets/cards/a_bad_workman_always_quarrels_with_his_tools.jpg',
        category: 'People & Life Stages',
        exampleSentence: 'When Ali failed to fix the car, he said the tools were useless but really, a bad workman always quarrels with his tools. Instead of blaming the computer for the mistakes, she should improve her typing skills, a bad workman always quarrels with his tools. He couldn’t bake the cake properly and said the oven was old, a bad workman always quarrels with his tools. The artist said the brushes were bad when his painting looked rough, truly, a bad workman always quarrels with his tools.',
      ),
      PictureWordEntry(
        word: 'A ballpark figure',
        partOfSpeech: 'Phrase',
        englishMeaning: 'An approximate number or rough estimate. A number that is not exact but is close enough to give a general idea. It is used when precision is not necessary or when only an estimate is available.',
        synonyms: ['Rough estimate', 'Approximation', 'Close estimate', 'Rule of thumb'],
        antonyms: ['Exact figure', 'Precise number', 'Accurate calculation'],
        imageUrl: 'assets/cards/a_ballpark_figure.jpg',
        thumbnailUrl: 'assets/cards/a_ballpark_figure.jpg',
        category: 'Science & Space',
        exampleSentence: 'Can you give me a ballpark figure for the total expenses?. The contractor provided a ballpark figure before starting the project. I do not need the exact amount, just a ballpark figure will do. The company estimated a ballpark figure for next year’s budget.',
      ),
      PictureWordEntry(
        word: 'A bird’s eye view',
        partOfSpeech: 'Idiom',
        englishMeaning: 'A general or overall view of something. To see or understand something from a high, broad, or general perspective, rather than looking at small details. It means having an overview of a situation, place, or subject.',
        synonyms: ['Overview', 'General idea'],
        antonyms: ['Detailed view', 'In-depth analysis', 'Microscopic view'],
        imageUrl: 'assets/cards/a_birds_eye_view.jpg',
        thumbnailUrl: 'assets/cards/a_birds_eye_view.jpg',
        category: 'Nature & Animals',
        exampleSentence: 'From the tower, we got a bird’s eye view of the city. From the plane, we got a bird’s eye view of the entire city. The report gives a bird’s eye view of the education system in Sindh. During the meeting, the manager presented a bird’s eye view of the company’s progress. This map provides a bird’s eye view of the disaster-affected areas.',
      ),
      PictureWordEntry(
        word: 'A blessing in disguise',
        partOfSpeech: 'Idiom',
        englishMeaning: 'Something that seems bad or unlucky at first but later turns out to be good. Hidden advantage in a difficult situation. Unexpected benefit from a problem. Good outcome from a bad beginning',
        synonyms: ['Hidden blessing', 'Silver lining', 'Unexpected benefit', 'Good fortune in adversity'],
        antonyms: ['Misfortune', 'Bad luck', 'Curse', 'Setback'],
        imageUrl: 'assets/cards/a_blessing_in_disguise.jpg',
        thumbnailUrl: 'assets/cards/a_blessing_in_disguise.jpg',
        category: 'Emotions & Feelings',
        exampleSentence: 'Losing that job was a blessing in disguise because I found a better one later. His illness was a blessing in disguise as it made him change his unhealthy lifestyle. Missing the flight turned out to be a blessing in disguise when the plane had technical issues. The failure in business was a blessing in disguise that taught her valuable lessons.',
      ),
      PictureWordEntry(
        word: 'A blur question',
        partOfSpeech: 'Phrase',
        englishMeaning: 'A question that is unclear, confusing, or not easily understood.',
        synonyms: ['Vague question', 'Confusing question', 'Uncertain inquiry'],
        antonyms: ['Clear question'],
        imageUrl: 'assets/cards/a_blur_question.jpg',
        thumbnailUrl: 'assets/cards/a_blur_question.jpg',
        category: 'General Vocabulary',
        exampleSentence: 'His explanation was so fast that it turned into a blur question for the students. When she spoke softly, her question sounded like a blur question to everyone. The interviewer’s blur question left the candidate unsure about how to answer. It is hard to respond correctly when the question itself is a blur question.',
      ),
      PictureWordEntry(
        word: 'A chink in someone’s armour',
        partOfSpeech: 'Idiom',
        englishMeaning: 'A small weakness in a person’s character, plan, or defense. It means a hidden flaw that can cause problems or make them vulnerable.',
        synonyms: ['Flaw', 'Weakness'],
        antonyms: ['Strength', 'Perfection'],
        imageUrl: 'assets/cards/a_chink_in_someones_armour.jpg',
        thumbnailUrl: 'assets/cards/a_chink_in_someones_armour.jpg',
        category: 'Law & Justice',
        exampleSentence: 'His arrogance is the only chink in his armour. The plan had a small chink in its armour. Every hero has a chink in his armour. That mistake showed a chink in his armour.',
      ),
      PictureWordEntry(
        word: 'A cog in the machine',
        partOfSpeech: 'Idiom',
        englishMeaning: 'A person who is just a small part of big organization or system. An unimportant or minor member of a large organization, system, or process, easily replaceable.',
        synonyms: ['Small part', 'Replaceable worker', 'Insignificant member'],
        antonyms: ['Key player', 'Essential member', 'Main contributor'],
        imageUrl: 'assets/cards/a_cog_in_the_machine.jpg',
        thumbnailUrl: 'assets/cards/a_cog_in_the_machine.jpg',
        category: 'Technology & Computing',
        exampleSentence: 'He felt like just a cog in the machine, doing the same work every day without recognition.\nIn a huge corporation, many employees see themselves as cogs in the machine. Though she’s a cog in the machine, her role is essential for the project’s success.',
      ),
      PictureWordEntry(
        word: 'A dark horse',
        partOfSpeech: 'Idiom',
        englishMeaning: 'A person whose abilities or plans are hidden and who surprises others by succeeding. A person who is not well known or expected to win or succeed, but later surprises everyone with unexpected success. It is often used in competitions, politics, or any situation where someone quietly performs better than expected.',
        synonyms: ['Surprise winner', 'Underdog', 'Unknown contender', 'Hidden talent', 'Sleeper candidate'],
        antonyms: ['Favorite', 'Front runner', 'Well known competitor', 'Predictable winner'],
        imageUrl: 'assets/cards/a_dark_horse.jpg',
        thumbnailUrl: 'assets/cards/a_dark_horse.jpg',
        category: 'People & Life Stages',
        exampleSentence: 'He was a dark horse in the election and ended up winning easily. Nobody expected her to top the class, but she turned out to be a dark horse. The small team was a dark horse in the tournament and defeated stronger opponents. That quiet employee is a dark horse with amazing skills.',
      ),
      PictureWordEntry(
        word: 'A dog in manger',
        partOfSpeech: 'Idiom',
        englishMeaning: 'A person who stops others from using something they do not need themselves. This idiom refers to someone who selfishly prevents others from benefiting from something even though they have no use for it themselves.',
        synonyms: ['Selfish person', 'Begrudger', 'Hoarder', 'Spiteful person'],
        antonyms: ['Generous person', 'Sharing', 'Kind hearted', 'Open handed'],
        imageUrl: 'assets/cards/a_dog_in_manger.jpg',
        thumbnailUrl: 'assets/cards/a_dog_in_manger.jpg',
        category: 'People & Life Stages',
        exampleSentence: 'He never uses the old computer but refuses to let anyone else have it. He is a dog in the manger. She kept the files locked even though she had no work to do with them, acting like a dog in the manger. The manager would not approve the plan nor allow others to improve it. A real dog in the manger. Keeping unused land idle while others need it is the behavior of a dog in the manger.',
      ),
      PictureWordEntry(
        word: 'A friend in need is a friend indeed',
        partOfSpeech: 'Idiom',
        englishMeaning: 'A true friend is one who helps you in difficult times. Real friendship shows during hardships, not in good times. A person who supports you when you need it most is a real friend. Difficult times reveal genuine relationships. Loyalty is proven through help during crises.',
        synonyms: ['True friend', 'Loyal companion', 'Faithful helper', 'Reliable friend', 'Steadfast supporter'],
        antonyms: ['Fair-weather friend', 'Betrayer', 'Disloyal companion', 'Selfish acquaintance', 'False friend'],
        imageUrl: 'assets/cards/a_friend_in_need_is_a_friend_indeed.jpg',
        thumbnailUrl: 'assets/cards/a_friend_in_need_is_a_friend_indeed.jpg',
        category: 'People & Life Stages',
        exampleSentence: 'When I was ill, he stayed by my side; a friend in need is a friend indeed. She helped me pay my bills, proving that a friend in need is a friend indeed. My cousin supported me during the tough time; truly a friend in need is a friend indeed. Only real friends stay in bad times, as a friend in need is a friend indeed.',
      ),
      PictureWordEntry(
        word: 'A going concern',
        partOfSpeech: 'Idiom',
        englishMeaning: 'A business or an activity that is making a profit and is expected to continue to do well. It can also be used generally to describe anything that is active, running, or functional.',
        synonyms: ['Successful business', 'Thriving enterprise', 'Flourishing venture', 'Profitable operation', 'Functioning entity'],
        antonyms: ['Failed business', 'Bankrupt entity', 'Defunct company', 'Collapsed venture', 'Non-functioning'],
        imageUrl: 'assets/cards/a_going_concern.jpg',
        thumbnailUrl: 'assets/cards/a_going_concern.jpg',
        category: 'Vehicles & Transport',
        exampleSentence: 'He sold the cafe as a going concern. They knew that, as a going concern, the cafe would command a higher price with prospective buyers. The factory is a going concern and is making steady profits. Their partnership is still a going concern after 10 years.',
      ),
      PictureWordEntry(
        word: 'A happy medium',
        partOfSpeech: 'Idiom',
        englishMeaning: 'A reasonable and practical balance between two opposite choices or opinions. It suggests avoiding excess on either side and choosing a middle path that combines the good aspects of both sides.',
        synonyms: ['Balance', 'Compromise'],
        antonyms: ['Extreme', 'Excess'],
        imageUrl: 'assets/cards/a_happy_medium.jpg',
        thumbnailUrl: 'assets/cards/a_happy_medium.jpg',
        category: 'Descriptive Qualities',
        exampleSentence: 'Let’s find a happy medium between work and rest. She always seeks a happy medium in arguments. We need a happy medium between freedom and order. The happy medium was a compromise both accepted.',
      ),
      PictureWordEntry(
        word: 'A hard nut to crack',
        partOfSpeech: 'Idiom',
        englishMeaning: 'Something or someone that is very difficult to understand, solve, or deal with. A tough problem, a difficult task, or a person who is not easy to influence, convince, or understand. It is often used in situations where effort, skill, or patience is required.',
        synonyms: ['Tough problem', 'Difficult task', 'Hard case', 'Challenge', 'Tough nut'],
        antonyms: ['Easy task', 'Simple problem', 'Piece of cake', 'Straightforward matter'],
        imageUrl: 'assets/cards/a_hard_nut_to_crack.jpg',
        thumbnailUrl: 'assets/cards/a_hard_nut_to_crack.jpg',
        category: 'Technology & Computing',
        exampleSentence: 'Solving this puzzle is a hard nut to crack. The new software bug turned out to be a hard nut to crack for the developers. He is a hard nut to crack when it comes to negotiations. Climate change is a hard nut to crack for global leaders.',
      ),
      PictureWordEntry(
        word: 'A hard nut to cut',
        partOfSpeech: 'Idiom',
        englishMeaning: 'A person or problem that is difficult to deal with, solve, or understand. Someone who is tough, stubborn, or not easily influenced, or a situation that requires effort, skill, and patience to handle successfully.',
        synonyms: ['Tough person', 'Difficult case', 'Hard problem', 'Tough challenge', 'Stubborn individual'],
        antonyms: ['Easy task', 'Simple problem', 'Gentle person', 'Manageable situation', 'Soft personality'],
        imageUrl: 'assets/cards/a_hard_nut_to_cut.jpg',
        thumbnailUrl: 'assets/cards/a_hard_nut_to_cut.jpg',
        category: 'People & Life Stages',
        exampleSentence: 'The new manager is a hard nut to cut and does not accept excuses. This puzzle is a hard nut to cut, even for experts. He proved to be a hard nut to cut during negotiations. Learning this language can be a hard nut to cut for beginners.',
      ),
      PictureWordEntry(
        word: 'A leopard does not change its spots',
        partOfSpeech: 'Idiom',
        englishMeaning: 'One cannot change their innate character. A person’s basic nature does not change. No matter how hard someone tries to appear different, their true character stays the same.',
        synonyms: ['Unchangeable', 'Ingrained'],
        antonyms: ['Changeable', 'Flexible'],
        imageUrl: 'assets/cards/a_leopard_does_not_change_its_spots.jpg',
        thumbnailUrl: 'assets/cards/a_leopard_does_not_change_its_spots.jpg',
        category: 'People & Life Stages',
        exampleSentence: 'Don’t trust him, a leopard does not change its spots. A leopard does not change its spots, so beware. She said a leopard does not change its spots. History shows a leopard does not change its spots.',
      ),
      PictureWordEntry(
        word: 'A part of furniture',
        partOfSpeech: 'Phrase',
        englishMeaning: 'An essential, regular item in a place. A person or thing that has been present in a place for so long that people hardly notice them anymore. Someone so familiar and common in a setting that they almost become invisible or unremarkable.',
        synonyms: ['Fixture', 'Regular', 'Familiar face'],
        antonyms: ['Accessory', 'Stranger', 'Visitor', 'Novice'],
        imageUrl: 'assets/cards/a_part_of_furniture.jpg',
        thumbnailUrl: 'assets/cards/a_part_of_furniture.jpg',
        category: 'People & Life Stages',
        exampleSentence: 'He has been teaching in this school for 40 years, he’s almost a part of the furniture now. She has been working in the same office for so long that people see her as part of the furniture. The old security guard at the bank is just like part of the furniture, everyone is used to him being there. He attends every meeting but never speaks; he’s just part of the furniture.',
      ),
      PictureWordEntry(
        word: 'A passport to',
        partOfSpeech: 'Idiom',
        englishMeaning: 'Something that gives a person the opportunity or access to achieve success or gain entry to something. A guarantee of entry into a field or profession. A strong advantage that improves social or professional status. A stepping stone toward higher achievement. A qualification that increases acceptance or recognition.',
        synonyms: ['Key to', 'Gateway to', 'Ticket to', 'Stepping stone to', 'Pathway to'],
        antonyms: ['Barrier to', 'Obstacle to', 'Hindrance to', 'Block to', 'Restriction on'],
        imageUrl: 'assets/cards/a_passport_to.jpg',
        thumbnailUrl: 'assets/cards/a_passport_to.jpg',
        category: 'Vehicles & Transport',
        exampleSentence: 'A good education is a passport to a successful career. Strong communication skills can be a passport to leadership roles. Hard work is often a passport to achievement. Networking can serve as a passport to new business opportunities.',
      ),
      PictureWordEntry(
        word: 'A penny for your thoughts',
        partOfSpeech: 'Idiom',
        englishMeaning: 'A polite way to ask someone what they are thinking. Asking gently about someone\'s thoughts. Encouraging someone to speak. Showing curiosity about silence. Friendly conversational opener. Used when someone appears quiet, thoughtful, or distracted. The speaker is inviting them to share their thoughts or feelings. It is friendly and informal.',
        synonyms: ['What are you thinking', 'Care to share your thoughts', 'What is on your mind', 'Tell me what you are thinking', 'Share your thoughts'],
        antonyms: ['Never mind', 'Keep it to yourself', 'I do not want to know', 'Say no more'],
        imageUrl: 'assets/cards/a_penny_for_your_thoughts.jpg',
        thumbnailUrl: 'assets/cards/a_penny_for_your_thoughts.jpg',
        category: 'People & Life Stages',
        exampleSentence: 'You have been quiet for a while, a penny for your thoughts. She looked out the window silently, and he said, a penny for your thoughts. A penny for your thoughts, you seem worried today. He smiled and asked, a penny for your thoughts, when she stopped talking.',
      ),
      PictureWordEntry(
        word: 'A picture is worth 1000 words',
        partOfSpeech: 'Proverb',
        englishMeaning: 'A single image can convey complex ideas, emotions, or stories better than a long description. Visuals often communicate more effectively than words.',
        synonyms: ['Visual expression'],
        antonyms: ['Wordy explanation'],
        imageUrl: 'assets/cards/a_picture_is_worth_1000_words.jpg',
        thumbnailUrl: 'assets/cards/a_picture_is_worth_1000_words.jpg',
        category: 'Music & Arts',
        exampleSentence: 'The chart explained everything, a picture is worth 1000 words. In a meeting, charts and infographics make the data easy to understand, proving that a picture is worth a thousand words. Instead of describing the beauty of the mountains, showing a photo of the snow-covered peaks makes the experience clear, a picture is worth a thousand words.',
      ),
      PictureWordEntry(
        word: 'A wet blanket',
        partOfSpeech: 'Idiom',
        englishMeaning: 'A person who spoils others’ fun or excitement. A person who discourages others or spoils the fun, enthusiasm, or excitement in a group or event.',
        synonyms: ['Killjoy', 'Spoilsport', 'Pessimist', 'Party Pooper', 'Grouch'],
        antonyms: ['Encourager', 'Motivator', 'Lively person', 'Cheerful companion', 'Optimist'],
        imageUrl: 'assets/cards/a_wet_blanket.jpg',
        thumbnailUrl: 'assets/cards/a_wet_blanket.jpg',
        category: 'People & Life Stages',
        exampleSentence: 'Everyone was dancing happily, but John was a wet blanket and refused to join. Don’t be a wet blanket; come and enjoy the celebration. His negative attitude always makes him a wet blanket in the team. She turned into a wet blanket when she started complaining about everything.',
      ),
      PictureWordEntry(
        word: 'A wild goose chase',
        partOfSpeech: 'Idiom',
        englishMeaning: 'A useless or impossible search. A futile or hopeless search or pursuit of something that is very difficult or impossible to find or achieve.',
        synonyms: ['Futile attempt'],
        antonyms: ['Productive search'],
        imageUrl: 'assets/cards/a_wild_goose_chase.jpg',
        thumbnailUrl: 'assets/cards/a_wild_goose_chase.jpg',
        category: 'Nature & Animals',
        exampleSentence: 'Searching for his lost pen was a wild goose chase. We spent the whole day looking for the missing file, but it turned out to be a wild goose chase. Searching for that old document in this huge office is a wild goose chase. He went on a wild goose chase trying to find a shop that sells that rare item. The detectives were on a wild goose chase because the clue was false.',
      ),
      PictureWordEntry(
        word: 'A wolf in sheep’s clothing',
        partOfSpeech: 'Idiom',
        englishMeaning: 'A person who hides malicious intent under a kind or innocent appearance. A deceiver pretending to be good. Outward appearance is gentle, but inner reality is harmful.',
        synonyms: ['Deceiver', 'Pretender', 'Hypocrite'],
        antonyms: ['Honest person', 'Truthful'],
        imageUrl: 'assets/cards/a_wolf_in_sheeps_clothing.jpg',
        thumbnailUrl: 'assets/cards/a_wolf_in_sheeps_clothing.jpg',
        category: 'People & Life Stages',
        exampleSentence: 'He seemed nice but turned out to be a wolf in sheep’s clothing. Beware of that man, he’s a wolf in sheep’s clothing. The politician was a wolf in sheep’s clothing. She trusted a wolf in sheep’s clothing and got hurt.',
      ),
      PictureWordEntry(
        word: 'Abandon',
        partOfSpeech: 'Verb, Noun',
        englishMeaning: 'To leave a person, place, or thing permanently. To stop supporting or continuing something such as a plan or belief. Behaving freely without control or restraint. A state of acting freely and without restraint.',
        synonyms: ['Deliver', 'Give up', 'Indulge', 'Surrender', 'Yield', 'Unconstraint', 'Unrestraint'],
        antonyms: ['Deny', 'Reclaim', 'Continue', 'Keep', 'Maintain', 'Constraint', 'Restraint'],
        imageUrl: 'assets/cards/abandon.jpg',
        thumbnailUrl: 'assets/cards/abandon.jpg',
        category: 'Vehicles & Transport',
        exampleSentence: 'The baby had been abandoned by its mother. The study showed a deep fear among the elderly of being abandoned to the care of strangers. Snow forced many drivers to abandon their vehicles. They had to abandon their lands to the invading forces. He spent money with careless abandon.',
      ),
      PictureWordEntry(
        word: 'Abase',
        partOfSpeech: 'Verb',
        englishMeaning: 'To lower someone in rank, dignity, or social standing. To humiliate or degrade a person deeply, causing loss of self-respect. To bring down the status or prestige of oneself or another through words or actions. To reduce someone to a state of shame or inferiority. To demean or belittle in a public or private setting.',
        synonyms: ['Humiliate', 'Degrade', 'Demean', 'Belittle', 'Disgrace'],
        antonyms: ['Elevate', 'Exalt', 'Honor', 'Uplift', 'Dignify'],
        imageUrl: 'assets/cards/abase.jpg',
        thumbnailUrl: 'assets/cards/abase.jpg',
        category: 'Actions & Processes',
        exampleSentence: 'He refused to abase himself before his rivals. The tyrant sought to abase those who opposed him. She would not abase her principles for anyone. The harsh criticism served only to abase his confidence. No one should abase another person to feel superior.',
      ),
      PictureWordEntry(
        word: 'Abash',
        partOfSpeech: 'Verb',
        englishMeaning: 'To make someone feel embarrassed, ashamed, or uneasy. To cause a person to feel self-conscious, disconcerted, or at a loss for words due to embarrassment or awkwardness. It often involves a sudden feeling of shame or confusion in a social context.',
        synonyms: ['Mortify', 'Embarrass', 'Shame', 'Humiliate', 'Disconcert', 'Fluster', 'Deflate'],
        antonyms: ['Encourage', 'Comfort', 'Reassure', 'Embolden'],
        imageUrl: 'assets/cards/abash.jpg',
        thumbnailUrl: 'assets/cards/abash.jpg',
        category: 'Emotions & Feelings',
        exampleSentence: 'He had never blushed in his life.  She was abashed by the unexpected praise in front of the crowd. He felt abashed when he realized his mistake. The teacher’s sharp question abashed the student. I was abashed to forget her birthday. His harsh critique abashed the young artist, making her question her skills. She was abashed from volunteering after hearing the challenging task.',
      ),
      PictureWordEntry(
        word: 'Abate',
        partOfSpeech: 'Verb',
        englishMeaning: 'To reduce in amount, degree, or intensity. To become less active, less widespread, or less severe. To remove or put an end to something. In law, to suspend, nullify, or deduct.',
        synonyms: ['Diminish', 'Lessen', 'Reduce', 'Subside', 'Ease', 'Mitigate', 'Relieve', 'Moderate'],
        antonyms: ['Increase', 'Intensify', 'Escalate', 'Worsen', 'Aggravate', 'Heighten'],
        imageUrl: 'assets/cards/abate.jpg',
        thumbnailUrl: 'assets/cards/abate.jpg',
        category: 'Nature & Animals',
        exampleSentence: 'The storm showed no signs of abating. They waited for the crowd’s fury to abate. Steps are to be taken to abate pollution. The fighting in the area shows no sign of abating.',
      ),
      PictureWordEntry(
        word: 'Abatement',
        partOfSpeech: 'Noun',
        englishMeaning: 'A gradual decrease in strength, amount, speed, or seriousness of something. The suspension, cancellation, or termination of a legal action or claim. Relief or lessening of pain, fever, or symptoms of illness.',
        synonyms: ['Deduction', 'Discount', 'Reduction', 'Curtailment', 'Abolishment', 'Abolition', 'Abrogation', 'Annulment'],
        antonyms: ['Accession', 'Addition', 'Boost', 'Enlargement', 'Gain', 'Increase', 'Increment'],
        imageUrl: 'assets/cards/abatement.jpg',
        thumbnailUrl: 'assets/cards/abatement.jpg',
        category: 'Actions & Processes',
        exampleSentence: 'The city spends \$9 million a year on air pollution abatement. No cure was possible, despite the abatement of symptoms. There was a noticeable abatement in the noise after midnight. The government announced a tax abatement for small businesses. She felt some abatement of pain after taking the medicine.',
      ),
      PictureWordEntry(
        word: 'Abbey',
        partOfSpeech: 'Noun',
        englishMeaning: 'A large church or monastery where monks or nuns live, work, and worship. It usually includes a church, living quarters, and other buildings used by members of a religious community.',
        synonyms: ['Convent', 'Cloister', 'Priory'],
        antonyms: ['Tavern', 'Marketplace', 'City hall', 'Public house', 'Secular building'],
        imageUrl: 'assets/cards/abbey.jpg',
        thumbnailUrl: 'assets/cards/abbey.jpg',
        category: 'Nature & Animals',
        exampleSentence: 'The monks have lived in the old abbey for over five centuries. Tourists visited the ancient abbey to admire its beautiful architecture. The abbey was surrounded by peaceful gardens and tall trees. He donated a large amount of money to restore the damaged abbey.',
      ),
      PictureWordEntry(
        word: 'Abbot',
        partOfSpeech: 'Noun',
        englishMeaning: 'The head and spiritual leader of a monastery or abbey. The chief monk elected by fellow monks to govern their religious community. A superior who holds administrative and spiritual authority over a group of monks. A religious title given to the person in charge of a monastic house. The overseer responsible for the welfare, discipline, and spiritual growth of all monks under his care.',
        synonyms: ['Prior', 'Superior', 'Prelate', 'Head monk', 'Archimandrite'],
        antonyms: ['Novice', 'Monk', 'Layman', 'Subordinate', 'Follower'],
        imageUrl: 'assets/cards/abbot.jpg',
        thumbnailUrl: 'assets/cards/abbot.jpg',
        category: 'People & Life Stages',
        exampleSentence: 'The abbot welcomed the pilgrims to the monastery. The elderly abbot guided his monks with great wisdom. The new abbot introduced several reforms to daily life. He was elected abbot after many years of devoted service. The abbot granted permission for visitors to tour the grounds.',
      ),
      PictureWordEntry(
        word: 'Abdicate',
        partOfSpeech: 'Verb',
        englishMeaning: 'To formally renounce or give up a throne, high office, or power. To step down voluntarily or under pressure from a position of authority or responsibility. To relinquish a right, duty, or privilege, especially one considered very important. To abandon a responsibility that one is expected to fulfill. To surrender control of a position of power, often in favor of a successor.',
        synonyms: ['Renounce', 'Resign', 'Relinquish', 'Step down', 'Surrender'],
        antonyms: ['Assume', 'Claim', 'Retain', 'Maintain', 'Accede'],
        imageUrl: 'assets/cards/abdicate.jpg',
        thumbnailUrl: 'assets/cards/abdicate.jpg',
        category: 'Vehicles & Transport',
        exampleSentence: 'The king decided to abdicate in favor of his son. She felt forced to abdicate her leadership role. The CEO chose to abdicate responsibility during the crisis. Rulers rarely abdicate willingly without external pressure. He abdicated his throne after thirty years of rule.',
      ),
      PictureWordEntry(
        word: 'Abdom',
        partOfSpeech: 'Noun',
        englishMeaning: 'An informal shortened form of abdomen, referring to the midsection of the body. The region of the torso between the chest and pelvis housing digestive and reproductive organs. The belly area encompassing the stomach, intestines, liver, and other vital organs. The central part of the trunk of the body below the diaphragm. The lower front section of the trunk, often associated with core muscle strength.',
        synonyms: ['Abdomen', 'Belly', 'Stomach', 'Midsection', 'Gut'],
        antonyms: ['Chest', 'Thorax', 'Back', 'Spine', 'Shoulder'],
        imageUrl: 'assets/cards/abdom.jpg',
        thumbnailUrl: 'assets/cards/abdom.jpg',
        category: 'Medical & Health',
        exampleSentence: 'He felt sharp pain in his abdom after eating. The doctor examined the patient\'s abdom carefully. After the workout, his abdom muscles were sore. She placed her hand gently on her abdom. The surgeon made a small incision in the lower abdom.',
      ),
      PictureWordEntry(
        word: 'Abdominal',
        partOfSpeech: 'Adjective',
        englishMeaning: 'Relating to or situated in the abdomen or stomach region. Pertaining to the muscles, organs, and tissues of the belly area. Of or connected with the digestive, reproductive, or excretory systems housed in the midsection. Describing exercises, surgeries, or conditions that involve the belly region. Referring to the anatomical area between the chest and the groin.',
        synonyms: ['Stomach', 'Belly', 'Ventral', 'Gastric', 'Intestinal'],
        antonyms: ['Dorsal', 'Spinal', 'Thoracic', 'Cranial', 'Cervical'],
        imageUrl: 'assets/cards/abdominal.jpg',
        thumbnailUrl: 'assets/cards/abdominal.jpg',
        category: 'Medical & Health',
        exampleSentence: 'He did fifty abdominal exercises every morning. The patient complained of severe abdominal pain. Strong abdominal muscles support the lower back. She underwent abdominal surgery to remove the tumor. Regular exercise helps strengthen abdominal muscles.',
      ),
      PictureWordEntry(
        word: 'Abduct',
        partOfSpeech: 'Verb',
        englishMeaning: 'To carry someone off illegally or by force, usually to hold them captive. Often used in legal, crime, or law enforcement contexts. To take something away unlawfully.',
        synonyms: ['Kidnap', 'Capture', 'Seize', 'Seizure', 'Carry off'],
        antonyms: ['Dorsal', 'Spinal', 'Thoracic', 'Cranial', 'Cervical'],
        imageUrl: 'assets/cards/abduct.jpg',
        thumbnailUrl: 'assets/cards/abduct.jpg',
        category: 'Law & Justice',
        exampleSentence: 'The gangsters planned to abduct the industrialist\'s young daughter and demand a huge ransom from her family. The criminals tried to abduct the child from the playground. The police rescued the woman who had been abducted.',
      ),
      PictureWordEntry(
        word: 'Aberrant',
        partOfSpeech: 'Adjective',
        englishMeaning: 'Not usual or not socially acceptable. Being or becoming different from the normal type. Different from what is typical or usual, especially in an unacceptable way.',
        synonyms: ['Abnormal', 'Deviant', 'Bizarre', 'Odd', 'Nonstandard', 'Exceptional', 'Anomalous', 'Atypical'],
        antonyms: ['Normal', 'Regular', 'Usual', 'Same', 'True', 'Common', 'Unexceptional', 'Ordinary'],
        imageUrl: 'assets/cards/aberrant.jpg',
        thumbnailUrl: 'assets/cards/aberrant.jpg',
        category: 'People & Life Stages',
        exampleSentence: 'The aim is to find the cause of the child\'s aberrant behavior. It reflects the aberrant personality of some American politicians hostile to China\'s development and becoming powerful. Now, this tree is aberrant in that it has two trunks.',
      ),
      PictureWordEntry(
        word: 'Aberration',
        partOfSpeech: 'Noun',
        englishMeaning: 'A departure from what is normal, expected, or typical; an unusual occurrence or behaviour that differs significantly from the standard.',
        synonyms: ['Anomaly', 'Deviation', 'Irregularity', 'Oddity', 'Divergence'],
        antonyms: ['Norm', 'Standard', 'Regularity', 'Conformity', 'Consistency'],
        imageUrl: 'assets/cards/aberration.jpg',
        thumbnailUrl: 'assets/cards/aberration.jpg',
        category: 'Music & Arts',
        exampleSentence: 'His violent outburst was described as a one-time aberration. The scientist noted an aberration in the experimental results. Her low grade was an aberration; she usually excels. Racism is a moral aberration that must be challenged.',
      ),
      PictureWordEntry(
        word: 'Abet',
        partOfSpeech: 'Verb',
        englishMeaning: 'To encourage, support, or assist someone in doing something wrong or illegal. To support, promote, or advance an action or cause indirectly. To foster or facilitate behavior, sometimes in a moral or ethical sense, not just legal.',
        synonyms: ['Assist', 'Encourage', 'Support', 'Aid', 'Help'],
        antonyms: ['Prevent', 'Discourage', 'Stop', 'Deter', 'Oppose'],
        imageUrl: 'assets/cards/abet.jpg',
        thumbnailUrl: 'assets/cards/abet.jpg',
        category: 'Law & Justice',
        exampleSentence: 'Any person who abets in tampering main pipeline will be punished 14 years rigorous imprisonment. He was arrested for abetting the robbery. She refused to abet her friend in cheating on the exam. Anyone who abets a criminal can face punishment under the law. The guard was accused of abetting the prisoners in their escape.',
      ),
      PictureWordEntry(
        word: 'Abey',
        partOfSpeech: 'Noun',
        englishMeaning: 'An archaic or rare form related to \'abeyance\', meaning to hold in a state of suspension or temporary inactivity. Not commonly used in modern English.',
        synonyms: ['Suspended', 'Dormant', 'Held back', 'Paused'],
        antonyms: ['Active', 'Ongoing', 'In progress'],
        imageUrl: 'assets/cards/abey.jpg',
        thumbnailUrl: 'assets/cards/abey.jpg',
        category: 'Law & Justice',
        exampleSentence: 'The matter was held in abey until further notice. The funds remained in abey for the entire fiscal year. The project was kept in abey pending approval. His appointment was left in abey by the committee.',
      ),
      PictureWordEntry(
        word: 'Abeyance',
        partOfSpeech: 'Noun',
        englishMeaning: 'A state of temporary suspension or inactivity. When something is in abeyance, it is paused, delayed, or held back until a later time.',
        synonyms: ['Suspension', 'Postponement', 'Dormancy', 'Inactivity', 'Hiatus'],
        antonyms: ['Activity', 'Continuity', 'Progress', 'Resolution'],
        imageUrl: 'assets/cards/abeyance.jpg',
        thumbnailUrl: 'assets/cards/abeyance.jpg',
        category: 'Law & Justice',
        exampleSentence: 'The project was held in abeyance due to lack of funds. The law remained in abeyance for several years. His ambitions fell into abeyance after the accident. The court kept the decision in abeyance pending appeal.',
      ),
      PictureWordEntry(
        word: 'Abeyancy',
        partOfSpeech: 'Noun',
        englishMeaning: 'A state of temporary suspension or inactivity; a condition of being held back or paused. Very similar to abeyance, referring to something temporarily set aside.',
        synonyms: ['Suspension', 'Dormancy', 'Inactivity', 'Postponement', 'Hiatus'],
        antonyms: ['Activity', 'Continuation', 'Progress', 'Action'],
        imageUrl: 'assets/cards/abeyancy.jpg',
        thumbnailUrl: 'assets/cards/abeyancy.jpg',
        category: 'Law & Justice',
        exampleSentence: 'The project remained in abeyancy until new funds arrived. The law was held in abeyancy pending a court review. His plans fell into abeyancy during the pandemic. The committee kept the decision in abeyancy for six months.',
      ),
      PictureWordEntry(
        word: 'Abhor',
        partOfSpeech: 'Verb',
        englishMeaning: 'To hate something, for example a way of behaving or thinking, especially for moral reasons. To regard with extreme repugnance, disgust, or aversion.',
        synonyms: ['Loathe', 'Detest'],
        antonyms: ['Admire', 'Approve', 'Esteem'],
        imageUrl: 'assets/cards/abhor.jpg',
        thumbnailUrl: 'assets/cards/abhor.jpg',
        category: 'Emotions & Feelings',
        exampleSentence: 'Most decent people abhor corruption in government. She abhors any form of cruelty towards animals. I abhor cruelty to animals. Many people abhor the idea of war. He abhors eating spicy food.',
      ),
      PictureWordEntry(
        word: 'Abject',
        partOfSpeech: 'Adjective',
        englishMeaning: 'Reduced to or existing in a state of utter hopelessness, degradation, or misery. Showing complete lack of pride or dignity; completely submissive and without self-respect. Extremely bad, terrible, or inadequate to an extreme degree. Characterized by deep humiliation and a sense of worthlessness. Marked by the absence of any moral or social standards, often applied to conditions of poverty or suffering.',
        synonyms: ['Wretched', 'Miserable', 'Degraded', 'Pitiful', 'Hopeless'],
        antonyms: ['Dignified', 'Noble', 'Proud', 'Exalted', 'Honorable'],
        imageUrl: 'assets/cards/abject.jpg',
        thumbnailUrl: 'assets/cards/abject.jpg',
        category: 'Emotions & Feelings',
        exampleSentence: 'They lived in abject poverty with no hope of improvement. His apology was so abject that everyone felt embarrassed. The refugees were found in abject conditions. She could not hide her abject misery. The failure of the project left him in a state of abject despair.',
      ),
      PictureWordEntry(
        word: 'Abjugate',
        partOfSpeech: 'Verb',
        englishMeaning: 'To free from a yoke, bondage, or oppressive control. To liberate a person or group from subjugation, servitude, or domination. To release from an obligation, constraint, or burden imposed by an external authority. To unyoke, untie, or set free from a state of forced obedience. To relieve someone from a condition of exploitation or subjection.',
        synonyms: ['Liberate', 'Free', 'Emancipate', 'Release', 'Unyoke'],
        antonyms: ['Enslave', 'Subjugate', 'Oppress', 'Bind', 'Yoke'],
        imageUrl: 'assets/cards/abjugate.jpg',
        thumbnailUrl: 'assets/cards/abjugate.jpg',
        category: 'People & Life Stages',
        exampleSentence: 'The revolution sought to abjugate the people from tyranny. The reformers worked to abjugate workers from exploitation. The king\'s decision to abjugate slaves was celebrated widely. Activists have long tried to abjugate communities from oppression. The treaty helped abjugate the conquered regions from foreign control.',
      ),
      PictureWordEntry(
        word: 'Abjure',
        partOfSpeech: 'Verb',
        englishMeaning: 'To formally reject, renounce, or give up a belief, claim, or practice. To give up something in a serious and public way. It often involves a formal declaration, especially when rejecting beliefs, religion, loyalty, or habits.',
        synonyms: ['Renounce', 'Reject', 'Forsake', 'Disown', 'Relinquish'],
        antonyms: ['Accept', 'Embrace', 'Support', 'Maintain', 'Uphold'],
        imageUrl: 'assets/cards/abjure.jpg',
        thumbnailUrl: 'assets/cards/abjure.jpg',
        category: 'Law & Justice',
        exampleSentence: 'He decided to abjure his bad habits and live a healthier life. The witness was forced to abjure his previous statement in court. She abjured her allegiance to the corrupt organization. Many leaders were asked to abjure violence and support peace.',
      ),
      PictureWordEntry(
        word: 'Ablution',
        partOfSpeech: 'Noun',
        englishMeaning: 'The washing of one\'s body or part of it (as in a religious rite). The act of washing yourself. A cleansing with water or other liquid, especially as a religious ritual. A washing of the hands, body, etc.',
        synonyms: ['Bath', 'Cleansing', 'Decontamination', 'Lavation', 'Shower', 'Purification', 'Showering'],
        antonyms: ['Pollution', 'Soilure', 'Defilement', 'Dirt', 'Contamination', 'Taint', 'Stain'],
        imageUrl: 'assets/cards/ablution.jpg',
        thumbnailUrl: 'assets/cards/ablution.jpg',
        category: 'Music & Arts',
        exampleSentence: 'The mosque used to cover an area of almost 2,000 square meters, with a main hall, a guest hall, and ablution room. Ablution is part of some religious ceremonies. I need to perform my ablutions!. He performed his ablution before the ritual.',
      ),
      PictureWordEntry(
        word: 'Abnegate',
        partOfSpeech: 'Verb',
        englishMeaning: 'To deny or renounce something, especially a right, desire, or privilege. To suppress or restrain one\'s own personal needs or wants for a higher cause. To reject or abandon a belief, faith, or affiliation. To surrender or give up something voluntarily, often in a spirit of self-discipline or sacrifice. To refuse to acknowledge or accept something that belongs to oneself.',
        synonyms: ['Renounce', 'Deny', 'Forsake', 'Relinquish', 'Surrender'],
        antonyms: ['Claim', 'Assert', 'Indulge', 'Retain', 'Accept'],
        imageUrl: 'assets/cards/abnegate.jpg',
        thumbnailUrl: 'assets/cards/abnegate.jpg',
        category: 'People & Life Stages',
        exampleSentence: 'The monk chose to abnegate all worldly pleasures. She decided to abnegate her claim to the inheritance. He had to abnegate his personal ambitions for the sake of the team. Soldiers sometimes abnegate their own comfort for their mission. The ascetic abnegated food and sleep to pursue spiritual wisdom.',
      ),
      PictureWordEntry(
        word: 'Abode',
        partOfSpeech: 'Noun',
        englishMeaning: 'A place where a person lives or stays, whether permanently or temporarily. A dwelling, home, or residence that serves as a shelter and living space. Any place considered a habitual residence or familiar place of rest. A house, apartment, cave, or any structure used as a living quarters. A fixed or settled place of living that one calls home.',
        synonyms: ['Home', 'Dwelling', 'Residence', 'Domicile', 'Habitat'],
        antonyms: ['Homelessness', 'Displacement', 'Vagrancy', 'Wandering', 'Exile'],
        imageUrl: 'assets/cards/abode.jpg',
        thumbnailUrl: 'assets/cards/abode.jpg',
        category: 'Science & Space',
        exampleSentence: 'Their humble abode was filled with laughter and warmth. He returned to his abode after a long journey. The cave served as the hermit\'s abode for many years. She decorated her abode with handmade crafts. Welcome to my abode — please make yourself at home.',
      ),
      PictureWordEntry(
        word: 'Abolish',
        partOfSpeech: 'Verb',
        englishMeaning: 'To formally put an end to a law, system, institution, or practice so that it no longer exists or is recognized. Often used in legal, social, and political contexts.',
        synonyms: ['Eliminate', 'Negate', 'Nullify', 'Abort'],
        antonyms: ['Protect', 'Preserve', 'Create'],
        imageUrl: 'assets/cards/abolish.jpg',
        thumbnailUrl: 'assets/cards/abolish.jpg',
        category: 'Law & Justice',
        exampleSentence: 'The sex should be abolished. The title of Giudice was abolished and a feudal marquisate substituted. Slavery was finally abolished in the United States in the nineteenth century.',
      ),
      PictureWordEntry(
        word: 'Abolition',
        partOfSpeech: 'Noun',
        englishMeaning: 'The formal act of officially ending, eliminating, or putting a complete stop to something. The legal or governmental process of cancelling a law, institution, or practice permanently. The movement or cause dedicated to ending slavery or any form of human oppression. The complete removal or eradication of something considered harmful or unjust. A decisive formal action by which a system or law is declared no longer in effect.',
        synonyms: ['Elimination', 'Cancellation', 'Eradication', 'Annulment', 'Dissolution'],
        antonyms: ['Establishment', 'Introduction', 'Retention', 'Continuation', 'Legalization'],
        imageUrl: 'assets/cards/abolition.jpg',
        thumbnailUrl: 'assets/cards/abolition.jpg',
        category: 'Law & Justice',
        exampleSentence: 'The abolition of slavery was a landmark moment in history. Many activists fought for the abolition of the death penalty. The abolition of child labor improved children\'s lives worldwide. The country celebrated the abolition of its oppressive tax laws. They campaigned for the abolition of cruel practices in prisons.',
      ),
      PictureWordEntry(
        word: 'Abort',
        partOfSpeech: 'Verb, Noun',
        englishMeaning: 'To end a process, mission, task, or action before it is completed, usually because continuing is unsafe, unnecessary, or not possible. Medical: to terminate a pregnancy (formal/clinical use)',
        synonyms: ['Cancel', 'Stop', 'Terminate', 'Halt', 'Discontinue', 'End', 'Call off'],
        antonyms: ['Continue', 'Proceed', 'Start', 'Begin', 'Resume', 'Carry on'],
        imageUrl: 'assets/cards/abort.jpg',
        thumbnailUrl: 'assets/cards/abort.jpg',
        category: 'Medical & Health',
        exampleSentence: 'The pilot decided to abort the landing due to bad weather. The system will abort the process if an error is detected. They had to abort the mission after technical failure. The doctor may abort the procedure if complications arise.',
      ),
    ];
  }
}
