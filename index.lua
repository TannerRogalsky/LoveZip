local Zip_mt = {}
local Zip = {}

local status, ffi = pcall(require, "ffi")
-- print(ffi.abi('le'))

ffi.cdef([[
  typedef struct __attribute__((packed)) {
    uint32_t header;                // offset 0
    uint16_t minVersion;            // offset 4
    uint16_t generalFlag;           // offset 6
    uint16_t compressionMethod;     // offset 8
    uint16_t lastModifiedTime;      // offset 10
    uint16_t lastModifiedData;      // offset 12
    uint32_t crc32;                 // offset 14
    uint32_t compressedSize;        // offset 18
    uint32_t uncompressedSize;      // offset 26
    uint16_t fileNameLength;        // offset 28
    uint16_t extraFieldLength;      // offset 30
    // uint8_t fileName[fileNameLength];
    // uint8_t extraField[extraFieldLength];
  } lua_zip_file_entry; // File record

  typedef struct __attribute__((packed)) {
    uint32_t header;                 // offset 0
    uint16_t version;                // offset 4
    uint16_t minVersion;             // offset 6
    uint16_t generalFlag;            // offset 8
    uint16_t compressionMethod;      // offset 10
    uint16_t lastModifiedTime;       // offset 12
    uint16_t lastModifiedData;       // offset 14
    uint32_t crc32;                  // offset 16
    uint32_t compressedSize;         // offset 20
    uint32_t uncompressedSize;       // offset 24
    uint16_t fileNameLength;         // offset 28
    uint16_t extraFieldLength;       // offset 30
    uint16_t fileCommentLength;      // offset 32
    uint16_t diskNumberFileStarts;   // offset 34
    uint16_t internalFileAttributes; // offset 36
    uint32_t externalFileAttributes; // offset 38
    uint32_t fileHeaderOffset;       // offset 42
    // uint8_t fileName[fileNameLength];
    // uint8_t extraField[extraFieldLength];
    // uint8_t fileComment[fileCommentLength];
  } lua_zip_central_directory; // Central Directory record

  typedef struct __attribute__((packed)) {
    uint32_t header;                  // offset 0
    uint16_t numberOfDisk;            // offset 4
    uint16_t diskWhereCentralDir;     // offset 6
    uint16_t numberCentralDirsOnDisk; // offset 8
    uint16_t totalCentralDirs;        // offset 10
    uint32_t sizeOfCentralDir;        // offset 12
    uint32_t offsetOfCentralDir;      // offset 16
    uint16_t commentLength;           // offset 20
    // uint8_t comment[commentLength];
  } lua_zip_eocd; // End Of Central Directory record

  typedef struct {
    union {
      uint32_t h;
      uint8_t b[4];
    };
  } lua_zip_header; // just useful, not important


  // https://github.com/hamishforbes/lua-ffi-zlib mostly
  // MIT License

  // Copyright (c) 2016 Hamish Forbes

  // Permission is hereby granted, free of charge, to any person obtaining a copy
  // of this software and associated documentation files (the "Software"), to deal
  // in the Software without restriction, including without limitation the rights
  // to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  // copies of the Software, and to permit persons to whom the Software is
  // furnished to do so, subject to the following conditions:

  // The above copyright notice and this permission notice shall be included in all
  // copies or substantial portions of the Software.

  // THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  // IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  // FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  // AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  // LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  // OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  // SOFTWARE.
  enum {
      Z_NO_FLUSH           = 0,
      Z_PARTIAL_FLUSH      = 1,
      Z_SYNC_FLUSH         = 2,
      Z_FULL_FLUSH         = 3,
      Z_FINISH             = 4,
      Z_BLOCK              = 5,
      Z_TREES              = 6,
      /* Allowed flush values; see deflate() and inflate() below for details */
      Z_OK                 = 0,
      Z_STREAM_END         = 1,
      Z_NEED_DICT          = 2,
      Z_ERRNO              = -1,
      Z_STREAM_ERROR       = -2,
      Z_DATA_ERROR         = -3,
      Z_MEM_ERROR          = -4,
      Z_BUF_ERROR          = -5,
      Z_VERSION_ERROR      = -6,
      /* Return codes for the compression/decompression functions. Negative values
      * are errors, positive values are used for special but normal events.
      */
      Z_NO_COMPRESSION      =  0,
      Z_BEST_SPEED          =  1,
      Z_BEST_COMPRESSION    =  9,
      Z_DEFAULT_COMPRESSION = -1,
      /* compression levels */
      Z_FILTERED            =  1,
      Z_HUFFMAN_ONLY        =  2,
      Z_RLE                 =  3,
      Z_FIXED               =  4,
      Z_DEFAULT_STRATEGY    =  0,
      /* compression strategy; see deflateInit2() below for details */
      Z_BINARY              =  0,
      Z_TEXT                =  1,
      Z_ASCII               =  Z_TEXT,   /* for compatibility with 1.2.2 and earlier */
      Z_UNKNOWN             =  2,
      /* Possible values of the data_type field (though see inflate()) */
      Z_DEFLATED            =  8,
      /* The deflate compression method (the only one supported in this version) */
      Z_NULL                =  0,  /* for initializing zalloc, zfree, opaque */
  };

  typedef void*    (* z_alloc_func)( void* opaque, unsigned items, unsigned size );
  typedef void     (* z_free_func) ( void* opaque, void* address );
  typedef struct z_stream_s {
     char*         next_in;
     unsigned      avail_in;
     unsigned long total_in;
     char*         next_out;
     unsigned      avail_out;
     unsigned long total_out;
     char*         msg;
     void*         state;
     z_alloc_func  zalloc;
     z_free_func   zfree;
     void*         opaque;
     int           data_type;
     unsigned long adler;
     unsigned long reserved;
  } z_stream;

  const char*   zlibVersion();
  const char*   zError(int);

  int inflate(z_stream*, int flush);
  int inflateEnd(z_stream*);
  int inflateInit2_(z_stream*, int windowBits, const char* version, int stream_size);
  int deflate(z_stream*, int flush);
  int deflateEnd(z_stream* );
  int deflateInit2_(z_stream*, int level, int method, int windowBits, int memLevel,int strategy, const char *version, int stream_size);

  uint32_t adler32(unsigned long adler, const char *buf, unsigned len);
  uint32_t crc32(unsigned long crc, const char *buf, unsigned len);

  uint32_t compressBound(uint32_t sourceLen);
  int compress2(uint8_t *dest, uint32_t *destLen, const uint8_t *source, uint32_t sourceLen, int level);
  int uncompress(uint8_t *dest, uint32_t *destLen, const uint8_t *source, uint32_t sourceLen);
]])

local FileEntry = ffi.typeof("lua_zip_file_entry")
local EOCD = ffi.typeof("lua_zip_eocd")
local CentralDirectory = ffi.typeof("lua_zip_central_directory")
local LuaZipHeader = ffi.typeof("lua_zip_header")

local function findBackwards(contents, start, header)
  for index=start,0,-1 do
    local all = true
    for i=0,3 do
      if header.b[i] ~= contents[index + i] then
        all = false
        break
      end
    end

    if all then
      return index
    end
  end
  return -1
end

local function compress(txt)
  local n = ffi.C.compressBound(#txt)
  local buf = ffi.new("uint8_t[?]", n)

  local stream = ffi.new('z_stream')
  stream.next_in = ffi.cast('uint8_t*', txt)
  stream.avail_in = #txt
  stream.next_out = buf
  stream.avail_out = n

  local version = ffi.C.zlibVersion()
  local windowBits = -15
  local level = ffi.C.Z_DEFAULT_COMPRESSION
  local method = ffi.C.Z_DEFLATED
  local strategy = ffi.C.Z_DEFAULT_STRATEGY

  local ret = ffi.C.deflateInit2_(stream, level, method, windowBits, 8, strategy, version, ffi.sizeof(stream))
  assert(ret == ffi.C.Z_OK, 'deflateInit2 error: ' .. ffi.string(ffi.C.zError(ret)))

  ret = ffi.C.deflate(stream, ffi.C.Z_FINISH)

  if ret ~= ffi.C.Z_STREAM_END then
    ffi.C.deflateEnd(stream)
    assert(false, 'deflate error: ' .. ffi.string(ffi.C.zError(ret)))
  end

  local compressedSize = stream.total_out
  local compressed = ffi.string(buf, compressedSize)
  ffi.C.deflateEnd(stream)
  return compressed, compressedSize
end


function Zip.new()
  return setmetatable({
    entries = {}
  }, {__index = Zip_mt})
end

function Zip_mt:add(filename, contents)
  self.entries[filename] = contents
end

function Zip_mt:remove(filename)
  self.entries[filename] = nil
end

function Zip_mt:compress()
  local centralDirectories = {}
  local files = {}
  local filesSize = 0
  for fileName,uncompressed in pairs(self.entries) do
    local uncompressedSize = #uncompressed
    local crc32, compressed, compressedSize = 0, nil, 0
    local compressionMethod = 0

    if uncompressed then -- file
      crc32 = ffi.C.crc32(0, uncompressed, uncompressedSize)
      compressed, compressedSize = compress(uncompressed)
      compressionMethod = 8
    else -- directory
      uncompressedSize = 0
    end

    local fileEntry = FileEntry()
    fileEntry.header = 0x04034b50
    fileEntry.minVersion = 788      -- is this good?
    fileEntry.generalFlag = 0       -- probably
    fileEntry.compressionMethod = compressionMethod
    -- https://love2d.org/wiki/love.filesystem.getLastModified
    fileEntry.lastModifiedTime = 0
    fileEntry.lastModifiedData = 0
    fileEntry.crc32 = crc32
    fileEntry.compressedSize = compressedSize
    fileEntry.uncompressedSize = uncompressedSize
    fileEntry.fileNameLength = #fileName
    fileEntry.extraFieldLength = 0

    table.insert(files, {
      record = fileEntry,
      fileName = fileName,
      compressed = compressed,
      offset = filesSize
    })

    local cd = CentralDirectory()
    cd.header = 0x02014b50
    cd.version = 800 -- eh?
    cd.minVersion = 788 -- plz
    cd.generalFlag = 0
    cd.compressionMethod = compressionMethod
    cd.lastModifiedTime = 0
    cd.lastModifiedData = 0
    cd.crc32 = crc32
    cd.compressedSize = compressedSize
    cd.uncompressedSize = uncompressedSize
    cd.fileNameLength = #fileName
    cd.extraFieldLength = 0
    cd.fileCommentLength = 0
    cd.diskNumberFileStarts = 0
    cd.internalFileAttributes = 0
    cd.externalFileAttributes = 0
    cd.fileHeaderOffset = filesSize

    table.insert(centralDirectories, {
      record = cd,
      fileName = fileName,
    })
    filesSize = filesSize
              + ffi.sizeof(FileEntry)
              + #fileName
              + compressedSize
  end

  local centralDirectoriesSize = 0
  for i,directory in ipairs(centralDirectories) do
    local fileName = directory.fileName
    local cd = directory.record
    directory.offset = filesSize + centralDirectoriesSize

    centralDirectoriesSize = centralDirectoriesSize
                           + ffi.sizeof(CentralDirectory)
                           + #fileName
  end

  local eocd = EOCD()
  eocd.header = 0x06054B50
  eocd.numberOfDisk = 0
  eocd.diskWhereCentralDir = 0
  eocd.numberCentralDirsOnDisk = #centralDirectories
  eocd.totalCentralDirs = #centralDirectories
  eocd.sizeOfCentralDir = centralDirectoriesSize
  eocd.offsetOfCentralDir = filesSize
  eocd.commentLength = 0

  local totalSize = filesSize + centralDirectoriesSize + ffi.sizeof(EOCD)
  local buffer = ffi.new('uint8_t[?]', totalSize)

  for i,fileEntry in ipairs(files) do
    local dataPtr = buffer + fileEntry.offset
    ffi.copy(dataPtr, fileEntry.record, ffi.sizeof(FileEntry))

    dataPtr = dataPtr + ffi.sizeof(FileEntry)
    ffi.copy(dataPtr, fileEntry.fileName, #fileEntry.fileName)

    if fileEntry.compressed then
      dataPtr = dataPtr + #fileEntry.fileName
      ffi.copy(dataPtr, fileEntry.compressed, #fileEntry.compressed)
    end
  end

  for i,cdEntry in ipairs(centralDirectories) do
    local dataPtr = buffer + cdEntry.offset
    ffi.copy(dataPtr, cdEntry.record, ffi.sizeof(CentralDirectory))
    ffi.copy(dataPtr + ffi.sizeof(CentralDirectory), cdEntry.fileName, #cdEntry.fileName)
  end

  ffi.copy(buffer + filesSize + centralDirectoriesSize, eocd, ffi.sizeof(EOCD))

  return ffi.string(buffer, totalSize)
end

function Zip.decompress(raw)
  local contents = ffi.cast("uint8_t*", raw)
  local eocdHeader = LuaZipHeader()
  eocdHeader.h = 0x06054b50;

  local eocdIndex = findBackwards(contents, #raw - ffi.sizeof(EOCD), eocdHeader)
  assert(eocdIndex >= 0, "End Of Central Directory header not found.")

  local eocd = EOCD()
  ffi.copy(eocd, contents + eocdIndex, ffi.sizeof(EOCD))

  local centralDirectories = {}
  local cdIndex = eocd.offsetOfCentralDir;
  for i=1,eocd.totalCentralDirs do
    local cdSize = ffi.sizeof(CentralDirectory)
    local cd = CentralDirectory()
    ffi.copy(cd, contents + cdIndex, cdSize)
    table.insert(centralDirectories, cd)
    cdIndex = cdIndex + cdSize +
              cd.fileNameLength +
              cd.extraFieldLength +
              cd.fileCommentLength
  end

  local files = {}
  for i,cd in ipairs(centralDirectories) do
    local file = FileEntry()
    local dataPtr = contents + cd.fileHeaderOffset
    ffi.copy(file, dataPtr, ffi.sizeof(FileEntry))
    assert(file.header == 0x04034b50, 'File Header is wrong.')

    local fileNamePtr = dataPtr + ffi.sizeof(FileEntry)
    local fileName = ffi.string(fileNamePtr, file.fileNameLength)

    local fileContentsPtr = dataPtr
                          + ffi.sizeof(FileEntry)
                          + file.fileNameLength
                          + file.extraFieldLength

    if file.compressionMethod == 0 then -- STORE
      local checksum = ffi.C.crc32(0, fileContentsPtr, file.uncompressedSize)
      assert(file.crc32 == checksum, "Checksums don't match: " .. file.crc32 .. ' != ' .. checksum)

      files[fileName] = ffi.string(fileContentsPtr, file.uncompressedSize)
    elseif file.compressionMethod == 8 then -- DEFLATE
      local uncompressedPtr = ffi.new('uint8_t[?]', file.uncompressedSize)

      local stream = ffi.new('z_stream')
      stream.next_in = fileContentsPtr
      stream.avail_in = file.compressedSize
      stream.next_out = uncompressedPtr
      stream.avail_out = file.uncompressedSize

      local version, streamsize = ffi.C.zlibVersion(), ffi.sizeof(stream)
      -- -15 AKA -MAX_WBITS makes zlib not look for headers
      local ret = ffi.C.inflateInit2_(stream, -15, version, streamsize)
      assert(ret == ffi.C.Z_OK, 'inflateInit2 error: ' .. ffi.string(ffi.C.zError(ret)))

      ret = ffi.C.inflate(stream, ffi.C.Z_FINISH);
      if ret ~= ffi.C.Z_STREAM_END then
        ffi.C.inflateEnd(stream)
        assert(false, 'inflateEnd error: ' .. ffi.string(ffi.C.zError(ret)))
      end

      local uncompressed = ffi.string(uncompressedPtr, file.uncompressedSize)

      local checksum = ffi.C.crc32(0, uncompressed, file.uncompressedSize)
      assert(file.crc32 == checksum, "Checksums don't match: " .. file.crc32 .. ' != ' .. checksum)

      files[fileName] = uncompressed
      ffi.C.inflateEnd(stream)
    else
      assert(false, "Only STORE or DEFLATE plz. Compression method: " .. file.compressionMethod)
    end
  end

  local zip = Zip()
  for k,v in pairs(files) do
    zip:add(k, v)
  end
  return zip
end

return setmetatable(Zip, {__call = Zip.new})
