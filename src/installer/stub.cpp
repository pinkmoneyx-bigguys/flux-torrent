/*
 * Bittorrent Client using Qt and libtorrent.
 * Copyright (C) 2026  Flux contributors
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 * In addition, as a special exception, the copyright holders give permission to
 * link this program with the OpenSSL project's "OpenSSL" library (or with
 * modified versions of it that use the same license as the "OpenSSL" library),
 * and distribute the linked executables. You must obey the GNU General Public
 * License in all respects for all of the code used other than "OpenSSL".  If you
 * modify file(s), you may extend this exception to your version of the file(s),
 * but you are not obligated to do so. If you do not wish to do so, delete this
 * exception statement from your version.
 */

// The setup's first stage: a small program with no dependencies (static runtime, Windows' own libraries)
// that carries Flux packed after its last byte (payload.h). It shows a splash, unpacks Flux into a
// temporary folder, then runs the setup's interface (FluxSetup.exe, in that folder, on Flux's own Qt)
// with its arguments, and removes the folder once that is done.

#include <windows.h>
#include <compressapi.h>
#include <dwmapi.h>

#include <algorithm>
// GDI+ needs min and max, which NOMINMAX takes away
namespace Gdiplus
{
    using std::max;
    using std::min;
}
#include <gdiplus.h>
#include <shellapi.h>
#include <shlobj.h>

#include <algorithm>
#include <atomic>
#include <cstdint>
#include <cstring>
#include <string>
#include <thread>
#include <vector>

#include "payload.h"

namespace
{
    constexpr UINT WM_PROGRESS = WM_APP + 1;  // wParam: progress in 1/1000
    constexpr UINT WM_UNPACKED = WM_APP + 2;  // wParam: 1 when everything is in place
    constexpr int WIDTH = 400;
    constexpr int HEIGHT = 156;

    HWND g_window = nullptr;
    int g_permille = 0;
    std::wstring g_status;
    std::wstring g_error;
    std::atomic_bool g_ok {false};

    // "Preparing the setup…" in the languages Flux speaks
    std::wstring preparingText()
    {
        wchar_t name[LOCALE_NAME_MAX_LENGTH] = {};
        ::LCIDToLocaleName(MAKELCID(::GetUserDefaultUILanguage(), SORT_DEFAULT), name, LOCALE_NAME_MAX_LENGTH, 0);
        const std::wstring lang = std::wstring(name).substr(0, 2);
        if (lang == L"ru") return L"Подготовка установки…";
        if (lang == L"uk") return L"Підготовка встановлення…";
        if (lang == L"de") return L"Installation wird vorbereitet…";
        if (lang == L"es") return L"Preparando la instalación…";
        if (lang == L"fr") return L"Préparation de l’installation…";
        if (lang == L"pt") return L"Preparando a instalação…";
        if (lang == L"pl") return L"Przygotowywanie instalacji…";
        if (lang == L"zh") return L"正在准备安装…";
        return L"Preparing the setup…";
    }

    std::wstring fromUtf8(const std::string &text)
    {
        const int n = ::MultiByteToWideChar(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), nullptr, 0);
        std::wstring out(n, L'\0');
        ::MultiByteToWideChar(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), out.data(), n);
        return out;
    }

    bool readAt(HANDLE file, const std::uint64_t offset, void *buffer, const DWORD size)
    {
        LARGE_INTEGER pos;
        pos.QuadPart = static_cast<LONGLONG>(offset);
        DWORD got = 0;
        return ::SetFilePointerEx(file, pos, nullptr, FILE_BEGIN) && ::ReadFile(file, buffer, size, &got, nullptr) && (got == size);
    }

    bool readNext(HANDLE file, void *buffer, const std::uint64_t size)
    {
        auto *p = static_cast<char *>(buffer);
        std::uint64_t left = size;
        while (left > 0)
        {
            const DWORD chunk = static_cast<DWORD>(std::min<std::uint64_t>(left, 64u << 20));
            DWORD got = 0;
            if (!::ReadFile(file, p, chunk, &got, nullptr) || (got != chunk))
                return false;
            p += got;
            left -= got;
        }
        return true;
    }

    void createParents(const std::wstring &path)
    {
        const size_t slash = path.find_last_of(L'\\');
        if (slash != std::wstring::npos)
            ::SHCreateDirectoryExW(nullptr, path.substr(0, slash).c_str(), nullptr);
    }

    // Unpacks the payload of `self` into `target`; on failure says why in g_error
    void unpack(const std::wstring &self, const std::wstring &target)
    {
        HANDLE file = ::CreateFileW(self.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, nullptr);
        if (file == INVALID_HANDLE_VALUE)
        {
            g_error = L"Cannot read the setup file.";
            ::PostMessageW(g_window, WM_UNPACKED, 0, 0);
            return;
        }

        bool ok = false;
        DECOMPRESSOR_HANDLE decompressor = nullptr;
        do
        {
            LARGE_INTEGER size {};
            ::GetFileSizeEx(file, &size);
            char trailer[FluxPayload::TRAILER_SIZE];
            if (!readAt(file, size.QuadPart - FluxPayload::TRAILER_SIZE, trailer, sizeof(trailer))
                || (std::memcmp(trailer + 8, FluxPayload::END, 8) != 0))
            {
                g_error = L"The setup file is damaged: download it again.";
                break;
            }
            std::uint64_t start = 0;
            std::memcpy(&start, trailer, sizeof(start));

            char magic[8];
            std::uint32_t count = 0;
            std::uint64_t total = 0;
            if (!readAt(file, start, magic, sizeof(magic)) || (std::memcmp(magic, FluxPayload::MAGIC, 8) != 0)
                || !readNext(file, &count, sizeof(count)) || !readNext(file, &total, sizeof(total)))
            {
                g_error = L"The setup file is damaged: download it again.";
                break;
            }
            if (!::CreateDecompressor(COMPRESS_ALGORITHM_LZMS, nullptr, &decompressor))
            {
                g_error = L"Windows cannot unpack the setup on this system.";
                break;
            }

            std::uint64_t done = 0;
            std::vector<char> packed;
            std::vector<char> data;
            bool failed = false;
            for (std::uint32_t i = 0; (i < count) && !failed; ++i)
            {
                std::uint16_t nameSize = 0;
                std::uint64_t rawSize = 0;
                std::uint64_t packedSize = 0;
                std::uint8_t method = 0;
                std::string name;
                if (!readNext(file, &nameSize, sizeof(nameSize)))
                {
                    failed = true;
                    break;
                }
                name.resize(nameSize);
                if (!readNext(file, name.data(), nameSize) || !readNext(file, &rawSize, sizeof(rawSize))
                    || !readNext(file, &packedSize, sizeof(packedSize)) || !readNext(file, &method, sizeof(method)))
                {
                    failed = true;
                    break;
                }
                packed.resize(static_cast<size_t>(packedSize));
                if ((packedSize > 0) && !readNext(file, packed.data(), packedSize))
                {
                    failed = true;
                    break;
                }

                const char *bytes = packed.data();
                if (method == FluxPayload::LZMS)
                {
                    data.resize(static_cast<size_t>(rawSize));
                    SIZE_T got = 0;
                    if (!::Decompress(decompressor, packed.data(), packed.size(), data.data(), data.size(), &got) || (got != rawSize))
                    {
                        failed = true;
                        break;
                    }
                    bytes = data.data();
                }

                std::wstring relative = fromUtf8(name);
                for (wchar_t &c : relative)
                {
                    if (c == L'/')
                        c = L'\\';
                }
                // a path that climbs out of the folder is not one this setup wrote
                if ((relative.find(L"..") != std::wstring::npos) || (relative.find(L':') != std::wstring::npos))
                {
                    failed = true;
                    break;
                }
                const std::wstring path = target + L"\\" + relative;
                createParents(path);
                HANDLE out = ::CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
                if (out == INVALID_HANDLE_VALUE)
                {
                    failed = true;
                    break;
                }
                std::uint64_t left = rawSize;
                const char *p = bytes;
                while (left > 0)
                {
                    const DWORD chunk = static_cast<DWORD>(std::min<std::uint64_t>(left, 64u << 20));
                    DWORD wrote = 0;
                    if (!::WriteFile(out, p, chunk, &wrote, nullptr) || (wrote != chunk))
                    {
                        failed = true;
                        break;
                    }
                    p += wrote;
                    left -= wrote;
                }
                ::CloseHandle(out);

                done += rawSize;
                ::PostMessageW(g_window, WM_PROGRESS, (total > 0) ? static_cast<WPARAM>(done * 1000 / total) : 1000, 0);
            }
            if (failed)
            {
                g_error = L"The setup could not be unpacked. Check the free space on drive C: and try again.";
                break;
            }
            ok = true;
        } while (false);

        if (decompressor)
            ::CloseDecompressor(decompressor);
        ::CloseHandle(file);
        g_ok = ok;
        ::PostMessageW(g_window, WM_UNPACKED, ok ? 1 : 0, 0);
    }

    // The wave of Flux's logo (24 x 24 grid: M3 8c4.5 0 4.5 8 9 8s4.5-8 9-8)
    void drawLogo(Gdiplus::Graphics &g, const float x, const float y, const float side, const float dpi)
    {
        using namespace Gdiplus;
        const float r = side * 0.25f;
        GraphicsPath tile;
        tile.AddArc(x, y, r * 2, r * 2, 180, 90);
        tile.AddArc(x + side - r * 2, y, r * 2, r * 2, 270, 90);
        tile.AddArc(x + side - r * 2, y + side - r * 2, r * 2, r * 2, 0, 90);
        tile.AddArc(x, y + side - r * 2, r * 2, r * 2, 90, 90);
        tile.CloseFigure();
        SolidBrush white {Color(255, 250, 250, 250)};
        g.FillPath(&white, &tile);

        const float s = side / 24.0f;
        const auto pt = [&](const float px, const float py) { return PointF(x + px * s, y + py * s); };
        GraphicsPath wave;
        wave.AddBezier(pt(3, 8), pt(7.5f, 8), pt(7.5f, 16), pt(12, 16));
        wave.AddBezier(pt(12, 16), pt(16.5f, 16), pt(16.5f, 8), pt(21, 8));
        Pen pen {Color(255, 10, 10, 10), 2.2f * s};
        pen.SetLineCap(LineCapRound, LineCapRound, DashCapRound);
        g.DrawPath(&pen, &wave);
        (void)dpi;
    }

    void paint(HWND hwnd)
    {
        using namespace Gdiplus;
        PAINTSTRUCT ps;
        HDC dc = ::BeginPaint(hwnd, &ps);
        RECT rc;
        ::GetClientRect(hwnd, &rc);
        const int w = rc.right;
        const int h = rc.bottom;
        const float k = ::GetDpiForWindow(hwnd) / 96.0f;

        Bitmap buffer {w, h};
        Graphics g {&buffer};
        g.SetSmoothingMode(SmoothingModeAntiAlias);
        g.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);
        SolidBrush background {Color(255, 10, 10, 10)};
        g.FillRectangle(&background, 0, 0, w, h);
        Pen border {Color(26, 255, 255, 255), 1.0f};
        g.DrawRectangle(&border, 0, 0, w - 1, h - 1);

        const float pad = 28 * k;
        const float logo = 44 * k;
        drawLogo(g, pad, pad, logo, k);

        FontFamily family {L"Segoe UI Variable Display"};
        const bool variable = family.IsAvailable();
        FontFamily fallback {L"Segoe UI"};
        const FontFamily &face = variable ? family : fallback;
        Font title {&face, 19 * k, FontStyleBold, UnitPixel};
        Font caption {&face, 13 * k, FontStyleRegular, UnitPixel};
        SolidBrush text {Color(255, 250, 250, 250)};
        SolidBrush dim {Color(255, 161, 161, 161)};
        const float tx = pad + logo + 16 * k;
        g.DrawString(L"Flux Torrent", -1, &title, PointF(tx, pad + 1 * k), &text);
        g.DrawString(g_error.empty() ? g_status.c_str() : L"", -1, &caption, PointF(tx, pad + 26 * k), &dim);

        // the progress bar, or what went wrong
        const float barY = h - pad - 4 * k;
        if (g_error.empty())
        {
            SolidBrush track {Color(255, 38, 38, 38)};
            SolidBrush fill {Color(255, 96, 165, 250)};
            const float barW = w - pad * 2;
            g.FillRectangle(&track, pad, barY, barW, 4 * k);
            g.FillRectangle(&fill, pad, barY, barW * g_permille / 1000.0f, 4 * k);
        }
        else
        {
            SolidBrush red {Color(255, 255, 100, 103)};
            const RectF box {pad, pad + logo + 12 * k, w - pad * 2, h - pad - logo - 24 * k};
            g.DrawString(g_error.c_str(), -1, &caption, box, nullptr, &red);
        }

        Graphics screen {dc};
        screen.DrawImage(&buffer, 0, 0);
        ::EndPaint(hwnd, &ps);
    }

    LRESULT CALLBACK windowProc(HWND hwnd, const UINT message, const WPARAM wParam, const LPARAM lParam)
    {
        switch (message)
        {
        case WM_PAINT:
            paint(hwnd);
            return 0;
        case WM_ERASEBKGND:
            return 1;
        case WM_NCHITTEST:
            return HTCAPTION;  // drag it anywhere
        case WM_PROGRESS:
            g_permille = static_cast<int>(wParam);
            ::InvalidateRect(hwnd, nullptr, FALSE);
            return 0;
        case WM_UNPACKED:
            ::PostQuitMessage(0);
            return 0;
        case WM_CLOSE:
            ::DestroyWindow(hwnd);
            return 0;
        case WM_DESTROY:
            ::PostQuitMessage(1);
            return 0;
        default:
            return ::DefWindowProcW(hwnd, message, wParam, lParam);
        }
    }

    HWND createSplash(HINSTANCE instance)
    {
        WNDCLASSEXW wc {sizeof(wc)};
        wc.style = CS_DROPSHADOW;
        wc.lpfnWndProc = windowProc;
        wc.hInstance = instance;
        wc.hCursor = ::LoadCursorW(nullptr, IDC_APPSTARTING);
        wc.hIcon = ::LoadIconW(instance, MAKEINTRESOURCEW(1));
        wc.lpszClassName = L"FluxSetupSplash";
        ::RegisterClassExW(&wc);

        // centred on the screen the mouse is on, in the screen's scale
        POINT cursor;
        ::GetCursorPos(&cursor);
        MONITORINFO info {sizeof(info)};
        ::GetMonitorInfoW(::MonitorFromPoint(cursor, MONITOR_DEFAULTTOPRIMARY), &info);
        HWND hwnd = ::CreateWindowExW(WS_EX_APPWINDOW, wc.lpszClassName, L"Flux Torrent", WS_POPUP, 0, 0, WIDTH, HEIGHT,
            nullptr, nullptr, instance, nullptr);
        const float k = ::GetDpiForWindow(hwnd) / 96.0f;
        const int w = static_cast<int>(WIDTH * k);
        const int h = static_cast<int>(HEIGHT * k);
        const RECT &work = info.rcWork;
        ::SetWindowPos(hwnd, nullptr, work.left + (work.right - work.left - w) / 2, work.top + (work.bottom - work.top - h) / 2,
            w, h, SWP_NOZORDER);

        // Windows 11: rounded corners
        const DWORD round = 2;  // DWMWCP_ROUND
        ::DwmSetWindowAttribute(hwnd, 33 /* DWMWA_WINDOW_CORNER_PREFERENCE */, &round, sizeof(round));
        ::ShowWindow(hwnd, SW_SHOW);
        ::UpdateWindow(hwnd);
        return hwnd;
    }

    // The arguments of this process, as written (everything after the program's own path)
    std::wstring ownArguments()
    {
        const wchar_t *line = ::GetCommandLineW();
        if (*line == L'"')
        {
            ++line;
            while (*line && (*line != L'"'))
                ++line;
            if (*line)
                ++line;
        }
        else
        {
            while (*line && (*line != L' ') && (*line != L'\t'))
                ++line;
        }
        while ((*line == L' ') || (*line == L'\t'))
            ++line;
        return line;
    }

    void removeFolder(const std::wstring &folder)
    {
        // the setup's files can stay locked a moment after it exits
        for (int attempt = 0; attempt < 20; ++attempt)
        {
            std::wstring from = folder;
            from.push_back(L'\0');
            SHFILEOPSTRUCTW op {};
            op.wFunc = FO_DELETE;
            op.pFrom = from.c_str();
            op.fFlags = FOF_NO_UI;
            if ((::SHFileOperationW(&op) == 0) && (::GetFileAttributesW(folder.c_str()) == INVALID_FILE_ATTRIBUTES))
                return;
            ::Sleep(500);
        }
    }
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int)
{
    ::SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

    wchar_t self[MAX_PATH * 4] = {};
    ::GetModuleFileNameW(nullptr, self, MAX_PATH * 4);
    wchar_t temp[MAX_PATH] = {};
    ::GetTempPathW(MAX_PATH, temp);
    const std::wstring folder = std::wstring(temp) + L"FluxSetup-" + std::to_wstring(::GetCurrentProcessId());
    ::SHCreateDirectoryExW(nullptr, folder.c_str(), nullptr);

    ULONG_PTR gdiplus = 0;
    Gdiplus::GdiplusStartupInput input;
    Gdiplus::GdiplusStartup(&gdiplus, &input, nullptr);

    g_status = preparingText();
    g_window = createSplash(instance);
    std::thread worker {unpack, std::wstring(self), folder};

    MSG msg;
    while (::GetMessageW(&msg, nullptr, 0, 0) > 0)
    {
        ::TranslateMessage(&msg);
        ::DispatchMessageW(&msg);
    }
    worker.join();

    int exitCode = 1;
    if (g_ok)
    {
        // the interface, from the unpacked folder (it runs on Flux's own Qt there)
        std::wstring command = L"\"" + folder + L"\\FluxSetup.exe\" --source \"" + folder + L"\" " + ownArguments();
        STARTUPINFOW si {sizeof(si)};
        PROCESS_INFORMATION pi {};
        if (::CreateProcessW(nullptr, command.data(), nullptr, nullptr, FALSE, 0, nullptr, folder.c_str(), &si, &pi))
        {
            // the splash stays until the interface is up
            ::WaitForInputIdle(pi.hProcess, 15000);
            ::Sleep(400);
            ::DestroyWindow(g_window);
            ::WaitForSingleObject(pi.hProcess, INFINITE);
            DWORD code = 1;
            ::GetExitCodeProcess(pi.hProcess, &code);
            exitCode = static_cast<int>(code);
            ::CloseHandle(pi.hThread);
            ::CloseHandle(pi.hProcess);
        }
        else
        {
            ::DestroyWindow(g_window);
            ::MessageBoxW(nullptr, L"The setup could not start.", L"Flux Torrent", MB_ICONERROR);
        }
    }
    else
    {
        ::DestroyWindow(g_window);
        ::MessageBoxW(nullptr, g_error.empty() ? L"The setup was stopped." : g_error.c_str(), L"Flux Torrent", MB_ICONERROR);
    }

    Gdiplus::GdiplusShutdown(gdiplus);
    removeFolder(folder);
    return exitCode;
}
