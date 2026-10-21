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

// fluxpack <stub.exe> <folder> <setup.exe>
// Makes Flux's setup: the stub, then every file of <folder> packed (see payload.h).

#include <windows.h>
#include <compressapi.h>

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

#include "payload.h"

namespace fs = std::filesystem;

namespace
{
    std::vector<char> readAll(const fs::path &path)
    {
        std::ifstream in {path, std::ios::binary};
        return {std::istreambuf_iterator<char>(in), std::istreambuf_iterator<char>()};
    }

    template <typename T>
    void put(std::ofstream &out, const T value)
    {
        out.write(reinterpret_cast<const char *>(&value), sizeof(value));
    }

    std::string utf8(const std::wstring &text)
    {
        const int n = ::WideCharToMultiByte(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), nullptr, 0, nullptr, nullptr);
        std::string out(n, '\0');
        ::WideCharToMultiByte(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), out.data(), n, nullptr, nullptr);
        return out;
    }
}

int wmain(const int argc, wchar_t **argv)
{
    if (argc != 4)
    {
        std::fwprintf(stderr, L"usage: fluxpack <stub.exe> <folder> <setup.exe>\n");
        return 2;
    }
    const fs::path stub {argv[1]};
    const fs::path folder {argv[2]};
    const fs::path output {argv[3]};

    std::vector<fs::path> files;
    std::uint64_t total = 0;
    for (const auto &entry : fs::recursive_directory_iterator(folder))
    {
        if (entry.is_regular_file())
        {
            files.push_back(entry.path());
            total += entry.file_size();
        }
    }
    std::sort(files.begin(), files.end());

    COMPRESSOR_HANDLE compressor = nullptr;
    if (!::CreateCompressor(COMPRESS_ALGORITHM_LZMS, nullptr, &compressor))
    {
        std::fwprintf(stderr, L"fluxpack: no LZMS compressor (error %lu)\n", ::GetLastError());
        return 1;
    }

    std::ofstream out {output, std::ios::binary | std::ios::trunc};
    const std::vector<char> stubBytes = readAll(stub);
    if (stubBytes.empty())
    {
        std::fwprintf(stderr, L"fluxpack: cannot read %ls\n", stub.c_str());
        return 1;
    }
    out.write(stubBytes.data(), static_cast<std::streamsize>(stubBytes.size()));

    const std::uint64_t payloadStart = stubBytes.size();
    out.write(FluxPayload::MAGIC, sizeof(FluxPayload::MAGIC));
    put(out, static_cast<std::uint32_t>(files.size()));
    put(out, total);

    std::uint64_t packedTotal = 0;
    for (const fs::path &file : files)
    {
        std::wstring relative = fs::relative(file, folder).wstring();
        std::replace(relative.begin(), relative.end(), L'\\', L'/');
        const std::string name = utf8(relative);
        const std::vector<char> data = readAll(file);

        std::vector<char> packed;
        std::uint8_t method = FluxPayload::STORED;
        if (!data.empty())
        {
            SIZE_T needed = 0;
            ::Compress(compressor, data.data(), data.size(), nullptr, 0, &needed);
            packed.resize(needed);
            SIZE_T size = 0;
            if (::Compress(compressor, data.data(), data.size(), packed.data(), packed.size(), &size) && (size < data.size()))
            {
                packed.resize(size);
                method = FluxPayload::LZMS;
            }
        }
        const std::vector<char> &bytes = (method == FluxPayload::LZMS) ? packed : data;

        put(out, static_cast<std::uint16_t>(name.size()));
        out.write(name.data(), static_cast<std::streamsize>(name.size()));
        put(out, static_cast<std::uint64_t>(data.size()));
        put(out, static_cast<std::uint64_t>(bytes.size()));
        put(out, method);
        out.write(bytes.data(), static_cast<std::streamsize>(bytes.size()));
        packedTotal += bytes.size();
    }
    ::CloseCompressor(compressor);

    put(out, payloadStart);
    out.write(FluxPayload::END, sizeof(FluxPayload::END));
    out.close();
    if (!out)
    {
        std::fwprintf(stderr, L"fluxpack: cannot write %ls\n", output.c_str());
        return 1;
    }
    std::wprintf(L"fluxpack: %zu files, %.1f MB packed into %.1f MB\n", files.size(), total / 1048576.0, packedTotal / 1048576.0);
    return 0;
}
