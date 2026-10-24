#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

#include <fstream>

static void LogBootWin(const std::string& msg) {
  std::ofstream ofs("windows_boot.log", std::ios::app);
  if (ofs.is_open()) {
    ofs << msg << std::endl;
  }
}

bool FlutterWindow::OnCreate() {
  LogBootWin("FlutterWindow::OnCreate started");
  if (!Win32Window::OnCreate()) {
    LogBootWin("Win32Window::OnCreate failed");
    return false;
  }

  RECT frame = GetClientArea();

  LogBootWin("Creating FlutterViewController...");
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    LogBootWin("Engine or view is null!");
    return false;
  }
  LogBootWin("Registering plugins...");
  RegisterPlugins(flutter_controller_->engine());
  LogBootWin("Setting child content...");
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    LogBootWin("SetNextFrameCallback triggered, calling this->Show()");
    this->Show();
  });
  LogBootWin("Calling this->Show() directly...");
  this->Show();

  flutter_controller_->ForceRedraw();
  LogBootWin("FlutterWindow::OnCreate succeeded!");

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
