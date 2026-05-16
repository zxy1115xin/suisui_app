#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <functional>
#include <memory>
#include <string>

// 一个支持高 DPI 的 Win32 窗口抽象基类，供需要自定义渲染和输入处理的类继承。
class Win32Window
{
public:
  struct Point
  {
    unsigned int x;
    unsigned int y;
    Point(unsigned int x, unsigned int y) : x(x), y(y) {}
  };

  struct Size
  {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  // 创建一个标题为 |title| 的 Win32 窗口，并使用 |origin| 和 |size| 设置位置与大小。
  // 新窗口会在默认显示器上创建。窗口尺寸会以物理像素传递给系统，
  // 因此该函数会根据默认显示器对宽高进行缩放，以保证显示尺寸一致。
  // 窗口在调用 |Show| 之前是不可见的。创建成功时返回 true。
  bool Create(const std::wstring &title, const Point &origin, const Size &size);

  // 显示当前窗口。窗口成功显示时返回 true。
  bool Show();

  // 释放与窗口关联的系统资源。
  void Destroy();

  // 将 |content| 插入窗口树中。
  void SetChildContent(HWND content);

  // 返回底层窗口句柄，便于设置图标和其他窗口属性。
  // 如果窗口已经销毁，则返回 nullptr。
  HWND GetHandle();

  // 如果为 true，关闭此窗口时会退出应用。
  void SetQuitOnClose(bool quit_on_close);

  // 返回一个表示当前客户区边界的 RECT。
  RECT GetClientArea();

protected:
  // 处理与路由关键窗口消息，包括鼠标、尺寸变化和 DPI 相关消息。
  // 具体处理会交给子类重写的成员函数。
  virtual LRESULT MessageHandler(HWND window,
                                 UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  // 在窗口创建时调用，允许子类完成窗口相关初始化。
  // 如果初始化失败，子类应返回 false。
  virtual bool OnCreate();

  // 在销毁时调用。
  virtual void OnDestroy();

private:
  friend class WindowClassRegistrar;

  // 由消息循环调用的系统回调。
  // 该函数处理 WM_NCCREATE 消息，并启用非客户区的自动 DPI 缩放，
  // 使非客户区能够自动响应 DPI 变化。其他消息由 MessageHandler 处理。
  static LRESULT CALLBACK WndProc(HWND const window,
                                  UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;

  // 获取 |window| 对应的类实例指针。
  static Win32Window *GetThisFromHandle(HWND const window) noexcept;

  // 更新窗口边框主题，使其与系统主题保持一致。
  static void UpdateTheme(HWND const window);

  bool quit_on_close_ = false;

  // 顶层窗口句柄。
  HWND window_handle_ = nullptr;

  // 承载内容的窗口句柄。
  HWND child_content_ = nullptr;
};

#endif // RUNNER_WIN32_WINDOW_H_
