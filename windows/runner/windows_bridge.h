#ifndef RUNNER_WINDOWS_BRIDGE_H_
#define RUNNER_WINDOWS_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <shellapi.h>

#include <array>
#include <memory>

class WindowsBridge {
 public:
  WindowsBridge(HWND window, flutter::BinaryMessenger* messenger);
  ~WindowsBridge();

  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam,
                     LRESULT* result);

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  flutter::EncodableValue GetEnvironment() const;
  void ShowContextMenu();
  void SendAction(const std::string& action);
  void SetClickThrough(bool enabled);
  void SetPetMode(bool taskbar_mode);
  void ApplyInputStyle();
  void UpdateVisibility();
  void SetTrayVisible(bool visible);
  bool IsStartWithWindowsEnabled() const;
  void SetStartWithWindows(bool enabled);

  HWND window_;
  NOTIFYICONDATA tray_icon_{};
  std::array<HICON, 6> tray_frames_{};
  size_t tray_frame_index_ = 0;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  bool click_through_ = false;
  bool taskbar_mode_ = false;
  bool paused_ = false;
  bool user_hidden_ = false;
  bool behavior_hidden_ = false;
  bool tray_added_ = false;
  int desktop_size_dip_ = 168;
};

#endif  // RUNNER_WINDOWS_BRIDGE_H_
