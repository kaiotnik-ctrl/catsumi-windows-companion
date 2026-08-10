#include "windows_bridge.h"

#include <algorithm>
#include <filesystem>
#include <iterator>
#include <string>

#include "resource.h"
#include "utils.h"

namespace {

constexpr UINT kTrayMessage = WM_APP + 73;
constexpr UINT_PTR kTrayAnimationTimer = 73;
constexpr UINT kTrayFrameDelayMs = 240;
constexpr UINT kMenuPause = 2001;
constexpr UINT kMenuClickThrough = 2002;
constexpr UINT kMenuStartWithWindows = 2003;
constexpr UINT kMenuHide = 2004;
constexpr UINT kMenuExit = 2005;
constexpr UINT kMenuSizeDecrease = 2006;
constexpr UINT kMenuSizeIncrease = 2007;
constexpr UINT kMenuSizeReset = 2008;
constexpr wchar_t kRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kRunValue[] = L"Catsumi";

const flutter::EncodableMap* Arguments(
    const flutter::MethodCall<flutter::EncodableValue>& call) {
  return std::get_if<flutter::EncodableMap>(call.arguments());
}

int GetInt(const flutter::EncodableMap* map, const char* key, int fallback = 0) {
  if (!map) return fallback;
  auto iterator = map->find(flutter::EncodableValue(key));
  if (iterator == map->end()) return fallback;
  if (const auto* value = std::get_if<int32_t>(&iterator->second)) return *value;
  if (const auto* value = std::get_if<int64_t>(&iterator->second)) {
    return static_cast<int>(*value);
  }
  return fallback;
}

bool GetBool(const flutter::EncodableMap* map, const char* key,
             bool fallback = false) {
  if (!map) return fallback;
  auto iterator = map->find(flutter::EncodableValue(key));
  if (iterator == map->end()) return fallback;
  if (const auto* value = std::get_if<bool>(&iterator->second)) return *value;
  return fallback;
}

bool IsDesktopWindow(HWND window, const wchar_t* class_name) {
  return window == GetShellWindow() || wcscmp(class_name, L"Progman") == 0 ||
         wcscmp(class_name, L"WorkerW") == 0;
}

std::string ProcessName(HWND window) {
  DWORD process_id = 0;
  GetWindowThreadProcessId(window, &process_id);
  if (process_id == 0) return {};

  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE,
                               process_id);
  if (!process) return {};

  wchar_t path[32768]{};
  DWORD path_size = static_cast<DWORD>(std::size(path));
  std::string name;
  if (QueryFullProcessImageName(process, 0, path, &path_size)) {
    name = Utf8FromUtf16(std::filesystem::path(path).filename().c_str());
  }
  CloseHandle(process);
  return name;
}

}  // namespace

WindowsBridge::WindowsBridge(HWND window, flutter::BinaryMessenger* messenger)
    : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "catsumi/windows", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  const HINSTANCE instance = GetModuleHandle(nullptr);
  for (size_t index = 0; index < tray_frames_.size(); ++index) {
    tray_frames_[index] = LoadIcon(
        instance, MAKEINTRESOURCE(IDI_TRAY_FRAME_0 + static_cast<int>(index)));
  }

  tray_icon_.cbSize = sizeof(NOTIFYICONDATA);
  tray_icon_.hWnd = window_;
  tray_icon_.uID = 1;
  tray_icon_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  tray_icon_.uCallbackMessage = kTrayMessage;
  tray_icon_.hIcon = tray_frames_[0];
  wcscpy_s(tray_icon_.szTip, L"Catsumi desktop pet");
  SetTrayVisible(true);
  SetTimer(window_, kTrayAnimationTimer, kTrayFrameDelayMs, nullptr);
}

WindowsBridge::~WindowsBridge() {
  KillTimer(window_, kTrayAnimationTimer);
  if (channel_) channel_->SetMethodCallHandler(nullptr);
  SetTrayVisible(false);
}

void WindowsBridge::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "getEnvironment") {
    result->Success(GetEnvironment());
    return;
  }
  if (call.method_name() == "setPosition") {
    const auto* arguments = Arguments(call);
    SetWindowPos(window_, HWND_TOPMOST, GetInt(arguments, "x"),
                 GetInt(arguments, "y"), 0, 0,
                 SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
    result->Success();
    return;
  }
  if (call.method_name() == "setVisible") {
    behavior_hidden_ = !GetBool(Arguments(call), "visible", true);
    UpdateVisibility();
    result->Success();
    return;
  }
  if (call.method_name() == "setPaused") {
    paused_ = GetBool(Arguments(call), "paused");
    result->Success();
    return;
  }
  if (call.method_name() == "setClickThrough") {
    SetClickThrough(GetBool(Arguments(call), "enabled"));
    result->Success();
    return;
  }
  if (call.method_name() == "setPetMode") {
    SetPetMode(GetBool(Arguments(call), "taskbar"));
    result->Success();
    return;
  }
  if (call.method_name() == "setPetSize") {
    desktop_size_dip_ =
        (std::clamp)(GetInt(Arguments(call), "size", 168), 96, 288);
    if (!taskbar_mode_) SetPetMode(false);
    result->Success();
    return;
  }
  if (call.method_name() == "beginDrag") {
    ReleaseCapture();
    SendMessage(window_, WM_NCLBUTTONDOWN, HTCAPTION, 0);
    result->Success();
    return;
  }
  if (call.method_name() == "showContextMenu") {
    ShowContextMenu();
    result->Success();
    return;
  }
  result->NotImplemented();
}

flutter::EncodableValue WindowsBridge::GetEnvironment() const {
  HWND foreground = GetForegroundWindow();
  if (!foreground || foreground == window_) foreground = GetShellWindow();

  wchar_t class_name[256]{};
  GetClassName(foreground, class_name, static_cast<int>(std::size(class_name)));
  wchar_t title[1024]{};
  GetWindowText(foreground, title, static_cast<int>(std::size(title)));
  const bool desktop_visible = IsDesktopWindow(foreground, class_name);

  HMONITOR monitor = MonitorFromWindow(foreground, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info{sizeof(MONITORINFO)};
  GetMonitorInfo(monitor, &monitor_info);

  RECT foreground_rect{};
  GetWindowRect(foreground, &foreground_rect);
  const RECT& monitor_rect = monitor_info.rcMonitor;
  const bool fullscreen = !desktop_visible && !IsIconic(foreground) &&
      foreground_rect.left <= monitor_rect.left &&
      foreground_rect.top <= monitor_rect.top &&
      foreground_rect.right >= monitor_rect.right &&
      foreground_rect.bottom >= monitor_rect.bottom;

  LASTINPUTINFO last_input{sizeof(LASTINPUTINFO)};
  GetLastInputInfo(&last_input);
  const auto idle_seconds =
      static_cast<int>((GetTickCount() - last_input.dwTime) / 1000);

  RECT window_rect{};
  GetWindowRect(window_, &window_rect);
  POINT cursor{};
  GetCursorPos(&cursor);

  flutter::EncodableMap values;
  values[flutter::EncodableValue("processName")] =
      flutter::EncodableValue(ProcessName(foreground));
  values[flutter::EncodableValue("windowTitle")] =
      flutter::EncodableValue(Utf8FromUtf16(title));
  values[flutter::EncodableValue("desktopVisible")] =
      flutter::EncodableValue(desktop_visible);
  values[flutter::EncodableValue("fullscreen")] =
      flutter::EncodableValue(fullscreen);
  values[flutter::EncodableValue("idleSeconds")] =
      flutter::EncodableValue(idle_seconds);
  values[flutter::EncodableValue("workLeft")] =
      flutter::EncodableValue(monitor_info.rcWork.left);
  values[flutter::EncodableValue("workTop")] =
      flutter::EncodableValue(monitor_info.rcWork.top);
  values[flutter::EncodableValue("workRight")] =
      flutter::EncodableValue(monitor_info.rcWork.right);
  values[flutter::EncodableValue("workBottom")] =
      flutter::EncodableValue(monitor_info.rcWork.bottom);
  values[flutter::EncodableValue("windowWidth")] =
      flutter::EncodableValue(window_rect.right - window_rect.left);
  values[flutter::EncodableValue("windowHeight")] =
      flutter::EncodableValue(window_rect.bottom - window_rect.top);
  values[flutter::EncodableValue("windowLeft")] =
      flutter::EncodableValue(window_rect.left);
  values[flutter::EncodableValue("windowTop")] =
      flutter::EncodableValue(window_rect.top);
  values[flutter::EncodableValue("cursorX")] =
      flutter::EncodableValue(cursor.x);
  values[flutter::EncodableValue("cursorY")] =
      flutter::EncodableValue(cursor.y);
  return flutter::EncodableValue(values);
}

void WindowsBridge::SetClickThrough(bool enabled) {
  click_through_ = enabled;
  ApplyInputStyle();
  UpdateVisibility();
}

void WindowsBridge::ApplyInputStyle() {
  LONG_PTR style = GetWindowLongPtr(window_, GWL_EXSTYLE);
  if (click_through_) {
    style |= WS_EX_TRANSPARENT;
  } else {
    style &= ~static_cast<LONG_PTR>(WS_EX_TRANSPARENT);
  }
  SetWindowLongPtr(window_, GWL_EXSTYLE, style);
  SetWindowPos(window_, nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE |
                   SWP_FRAMECHANGED);
}

void WindowsBridge::SetPetMode(bool taskbar_mode) {
  taskbar_mode_ = taskbar_mode;

  if (taskbar_mode_) {
    // The tray icon is the only taskbar presence; hide the animated window.
    UpdateVisibility();
    ApplyInputStyle();
    return;
  }

  HWND foreground = GetForegroundWindow();
  if (!foreground || foreground == window_) foreground = window_;
  HMONITOR monitor = MonitorFromWindow(foreground, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info{sizeof(MONITORINFO)};
  GetMonitorInfo(monitor, &info);

  const UINT dpi = GetDpiForWindow(window_);
  RECT current{};
  GetWindowRect(window_, &current);
  int x = current.left;
  int y = current.top;
  int size = MulDiv(desktop_size_dip_, dpi, 96);

  x = (std::clamp)(x, static_cast<int>(info.rcWork.left),
                   static_cast<int>(info.rcWork.right) - size);
  y = info.rcWork.bottom - size;

  SetWindowPos(window_, HWND_TOPMOST, x, y, size, size,
               SWP_NOACTIVATE);
  ApplyInputStyle();
  UpdateVisibility();
}

void WindowsBridge::UpdateVisibility() {
  if (user_hidden_ || behavior_hidden_ || taskbar_mode_) {
    ShowWindow(window_, SW_HIDE);
    SetTrayVisible(true);
  } else {
    ShowWindow(window_, SW_SHOWNOACTIVATE);
    // Click-through makes the pet unable to receive right-clicks. Keep the
    // tray controller available until click-through is disabled again.
    SetTrayVisible(click_through_);
  }
}

void WindowsBridge::SetTrayVisible(bool visible) {
  if (visible == tray_added_) return;
  if (visible) {
    tray_icon_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    tray_icon_.hIcon = tray_frames_[tray_frame_index_];
    Shell_NotifyIcon(NIM_ADD, &tray_icon_);
    tray_icon_.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIcon(NIM_SETVERSION, &tray_icon_);
    tray_added_ = true;
  } else {
    Shell_NotifyIcon(NIM_DELETE, &tray_icon_);
    tray_added_ = false;
  }
}

bool WindowsBridge::IsStartWithWindowsEnabled() const {
  HKEY key = nullptr;
  if (RegOpenKeyEx(HKEY_CURRENT_USER, kRunKey, 0, KEY_QUERY_VALUE, &key) !=
      ERROR_SUCCESS) {
    return false;
  }
  const LSTATUS status = RegQueryValueEx(key, kRunValue, nullptr, nullptr,
                                        nullptr, nullptr);
  RegCloseKey(key);
  return status == ERROR_SUCCESS;
}

void WindowsBridge::SetStartWithWindows(bool enabled) {
  HKEY key = nullptr;
  if (RegCreateKeyEx(HKEY_CURRENT_USER, kRunKey, 0, nullptr, 0, KEY_SET_VALUE,
                     nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return;
  }
  if (enabled) {
    wchar_t executable[MAX_PATH]{};
    GetModuleFileName(nullptr, executable, MAX_PATH);
    const std::wstring quoted = L"\"" + std::wstring(executable) + L"\"";
    RegSetValueEx(key, kRunValue, 0, REG_SZ,
                  reinterpret_cast<const BYTE*>(quoted.c_str()),
                  static_cast<DWORD>((quoted.size() + 1) * sizeof(wchar_t)));
  } else {
    RegDeleteValue(key, kRunValue);
  }
  RegCloseKey(key);
}

void WindowsBridge::SendAction(const std::string& action) {
  if (channel_) {
    channel_->InvokeMethod("trayAction",
                           std::make_unique<flutter::EncodableValue>(action));
  }
}

void WindowsBridge::ShowContextMenu() {
  HMENU menu = CreatePopupMenu();
  AppendMenu(menu, MF_STRING | (paused_ ? MF_CHECKED : 0), kMenuPause,
             paused_ ? L"Resume animations" : L"Pause animations");
  AppendMenu(menu, MF_STRING | (click_through_ ? MF_CHECKED : 0),
             kMenuClickThrough, L"Click-through mode");
  AppendMenu(menu,
             MF_STRING | (desktop_size_dip_ <= 96 ? MF_GRAYED : 0),
             kMenuSizeDecrease, L"Decrease cat size");
  AppendMenu(menu,
             MF_STRING | (desktop_size_dip_ >= 288 ? MF_GRAYED : 0),
             kMenuSizeIncrease, L"Increase cat size");
  AppendMenu(menu,
             MF_STRING | (desktop_size_dip_ == 168 ? MF_GRAYED : 0),
             kMenuSizeReset, L"Reset cat size");
  AppendMenu(menu,
             MF_STRING | (IsStartWithWindowsEnabled() ? MF_CHECKED : 0),
             kMenuStartWithWindows, L"Start with Windows");
  AppendMenu(menu, MF_STRING, kMenuHide,
             user_hidden_ ? L"Show Catsumi" : L"Hide Catsumi");
  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenu(menu, MF_STRING, kMenuExit, L"Exit Catsumi");

  POINT cursor{};
  GetCursorPos(&cursor);
  SetForegroundWindow(window_);
  const UINT selection = TrackPopupMenu(
      menu, TPM_RETURNCMD | TPM_RIGHTBUTTON | TPM_NONOTIFY, cursor.x, cursor.y,
      0, window_, nullptr);
  DestroyMenu(menu);

  switch (selection) {
    case kMenuPause:
      paused_ = !paused_;
      SendAction("pause");
      break;
    case kMenuClickThrough:
      SendAction("clickThrough");
      break;
    case kMenuSizeDecrease:
      SendAction("sizeDecrease");
      break;
    case kMenuSizeIncrease:
      SendAction("sizeIncrease");
      break;
    case kMenuSizeReset:
      SendAction("sizeReset");
      break;
    case kMenuStartWithWindows:
      SetStartWithWindows(!IsStartWithWindowsEnabled());
      break;
    case kMenuHide:
      user_hidden_ = !user_hidden_;
      UpdateVisibility();
      break;
    case kMenuExit:
      PostMessage(window_, WM_CLOSE, 0, 0);
      break;
  }
}

bool WindowsBridge::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam,
                                  LRESULT* result) {
  if (message == WM_TIMER && wparam == kTrayAnimationTimer) {
    tray_frame_index_ = (tray_frame_index_ + 1) % tray_frames_.size();
    if (tray_added_) {
      tray_icon_.uFlags = NIF_ICON;
      tray_icon_.hIcon = tray_frames_[tray_frame_index_];
      Shell_NotifyIcon(NIM_MODIFY, &tray_icon_);
    }
    *result = 0;
    return true;
  }

  if (message != kTrayMessage) return false;
  const UINT event = LOWORD(lparam);
  if (event == WM_RBUTTONUP || event == WM_CONTEXTMENU) {
    ShowContextMenu();
  } else if (event == NIN_SELECT || event == WM_LBUTTONUP) {
    user_hidden_ = false;
    behavior_hidden_ = false;
    SetPetMode(false);
    SendAction("summon");
  }
  *result = 0;
  return true;
}
