status, ffi = pcall(require, "ffi")
-- print(ffi.abi('le'))

io.input('zip.h')
ffi.cdef(io.read('*all'))
FileEntry = ffi.typeof("lua_zip_file_entry")
EOCD = ffi.typeof("lua_zip_eocd")
CentralDirectory = ffi.typeof("lua_zip_central_directory")
LuaZipHeader = ffi.typeof("lua_zip_header")

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

do
  local raw = love.filesystem.read('control.zip')
  -- local raw = love.filesystem.read('test.zip')
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
      assert(ret == ffi.C.Z_OK, 'ZLIB error: ' .. ret)

      ret = ffi.C.inflate(stream, ffi.C.Z_FINISH);
      if ret ~= ffi.C.Z_STREAM_END then
        ffi.C.inflateEnd(stream)
        assert(false, 'ZLIB error: ' .. ret)
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
end

local function require_all(list, directory)
  local lfs = love.filesystem
  for index,filename in ipairs(lfs.getDirectoryItems(directory)) do
    if filename:sub(1, 1) ~= '.' then
      local file = directory .. "/" .. filename
      table.insert(list, file)
      if lfs.isDirectory(file) then
        require_all(list, file)
      end
    end
  end
  return list
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
  if ret ~= ffi.C.Z_OK then
    assert(false, "ZLIB init compress error: " .. ret)
  end

  ret = ffi.C.deflate(stream, ffi.C.Z_FINISH)

  if ret ~= ffi.C.Z_STREAM_END then
    ffi.C.deflateEnd(stream)
    assert(false, "ZLIB compress error: " .. ret)
  end

  local compressedSize = stream.total_out
  local compressed = ffi.string(buf, compressedSize)
  ffi.C.deflateEnd(stream)
  return compressed, compressedSize
end

do
  local list = require_all({}, 'test')
  -- list = {'test/main.lua'}

  io.output('test.zip')

  local centralDirectories = {}
  local currentOffset = 0
  for i,fileName in ipairs(list) do
    local uncompressed, uncompressedSize = love.filesystem.read(fileName)
    local crc32, compressed, compressedSize = 0, nil, 0
    local compressionMethod = 0

    if uncompressed then -- file
      crc32 = ffi.C.crc32(0, uncompressed, uncompressedSize)
      compressed, compressedSize = compress(uncompressed)
      compressionMethod = 8
    else -- directory
      fileName = fileName .. '/' -- entry isn't recognized as a folder without this!?
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

    io.write(ffi.string(fileEntry, ffi.sizeof(fileEntry)))
    io.write(fileName)
    if compressed then
      io.write(compressed)
    end

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
    cd.fileHeaderOffset = currentOffset

    table.insert(centralDirectories, {
      fileName = fileName,
      record = cd
    })
    currentOffset = currentOffset
                  + ffi.sizeof(FileEntry)
                  + #fileName
                  + compressedSize
  end

  local centralDirectoriesSize = 0
  for i,directory in ipairs(centralDirectories) do
    local fileName = directory.fileName
    local cd = directory.record

    io.write(ffi.string(cd, ffi.sizeof(CentralDirectory)))
    io.write(fileName)

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
  eocd.offsetOfCentralDir = currentOffset
  eocd.commentLength = 0

  io.write(ffi.string(eocd, ffi.sizeof(EOCD)))
end

love.event.push("quit")
