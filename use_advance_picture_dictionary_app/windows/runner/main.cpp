#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

#include <fstream>

static void LogBoot(const std::string& msg) {
  std::ofstream ofs("windows_boot.log", std::ios::app);
  if (ofs.is_open()) {
    ofs << msg << std::endl;
  }
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  LogBoot("wWinMain started");
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  // Disable experimental Impeller backend on Windows to prevent 0xc0000005 access violation crashes
  project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  LogBoot("Calling window.Create...");
  if (!window.Create(L"USE Advance Picture Dictionary", origin, size)) {
    LogBoot("window.Create returned FALSE!");
    return EXIT_FAILURE;
  }
  LogBoot("window.Create returned TRUE, calling window.Show()...");
  window.Show();
  window.SetQuitOnClose(true);

  LogBoot("Entering message loop...");
  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  LogBoot("Message loop ended, exiting.");
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
