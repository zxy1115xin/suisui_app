#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

// 为进程创建控制台，并将 stdout 和 stderr 重定向到该控制台，
// 供运行器和 Flutter 库共同使用。
void CreateAndAttachConsole();

// 接收一个以 null 结尾、UTF-16 编码的 wchar_t*，返回一个 UTF-8 编码的 std::string。
// 失败时返回空字符串。
std::string Utf8FromUtf16(const wchar_t *utf16_string);

// 获取命令行参数，并以 UTF-8 编码的 std::vector<std::string> 形式返回。
// 失败时返回空 vector。
std::vector<std::string> GetCommandLineArguments();

#endif // RUNNER_UTILS_H_
