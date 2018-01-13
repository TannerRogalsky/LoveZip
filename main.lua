io.input('zip.h')
local header = io.read('*all')

status, ffi = pcall(require, "ffi")
-- print(ffi.abi('le'))

ffi.cdef(header)
FileEntry = ffi.typeof("lua_zip_file_entry")
EOCD = ffi.typeof("lua_zip_eocd")
CentralDirectory = ffi.typeof("lua_zip_central_directory")
LuaZipHeader = ffi.typeof("lua_zip_header")
local ptrSize = ffi.sizeof("void*")

local function findBackwards(contents, size, header)
  for index=size - 4 - 1,0,-1 do
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

-- local function crc32(in)
--   local checksum = ()
-- end

do
  local raw = love.filesystem.read('control.zip')
  -- local raw = love.filesystem.read('test.dat')
  local contents = ffi.cast("uint8_t*", raw)
  local eocdHeader = LuaZipHeader()
  eocdHeader.h = 0x06054B50;

  local eocdIndex = findBackwards(contents, #raw, eocdHeader)
  assert(eocdIndex >= 0, "End Of Central Directory header not found.")

  local eocd = EOCD()
  ffi.copy(eocd, contents + eocdIndex, ffi.sizeof(EOCD))
  -- print('numberOfDisk', eocd.numberOfDisk)
  -- print('diskWhereCentralDir', eocd.diskWhereCentralDir)
  -- print('numberCentralDirsOnDisk', eocd.numberCentralDirsOnDisk)
  -- print('totalCentralDirs', eocd.totalCentralDirs)
  -- print('sizeOfCentralDir', eocd.sizeOfCentralDir)
  -- print('offsetOfCentralDir', eocd.offsetOfCentralDir)
  -- print('commentLength', eocd.commentLength)

  local cdHeader = LuaZipHeader()
  cdHeader.h = 0x02014b50
  local cdIndex = findBackwards(contents, eocdIndex, cdHeader)
  assert(cdIndex >= 0, "Central Directory header not found.")
  local cdSize = ffi.sizeof(CentralDirectory)
  local cd = CentralDirectory()
  ffi.copy(cd, contents + cdIndex, cdSize)
  -- TODO compressionMethod 0 = no compression
  assert(cd.compressionMethod == 8, "Only DEFLATE plz.")
  -- print('version', cd.version)
  -- print('minVersion', cd.minVersion)
  -- print('generalFlag', cd.generalFlag)
  -- print('compressionMethod', cd.compressionMethod)
  -- print('lastModifiedTime', cd.lastModifiedTime)
  -- print('lastModifiedData', cd.lastModifiedData)
  -- print('crc32', cd.crc32)
  -- print('compressedSize', cd.compressedSize)
  -- print('uncompressedSize', cd.uncompressedSize)
  -- print('fileNameLength', cd.fileNameLength)
  -- print('extraFieldLength', cd.extraFieldLength)
  -- print('fileCommentLength', cd.fileCommentLength)
  -- print('diskNumberFileStarts', cd.diskNumberFileStarts)
  -- print('internalFileAttributes', cd.internalFileAttributes)
  -- print('externalFileAttributes', cd.externalFileAttributes)
  -- print('fileHeaderOffset', cd.fileHeaderOffset)

  local fileNamePtr = contents + cdIndex + cdSize + ptrSize * 0
  local fileName = ffi.string(fileNamePtr, cd.fileNameLength)
  print(fileName)

  local file = FileEntry()
  ffi.copy(file, contents + cd.fileHeaderOffset, ffi.sizeof(FileEntry))
  assert(file.header == 0x04034b50, 'File Header is wrong.')
  -- print(file.fileNameLength)
  -- print(file.extraFieldLength)
  -- print(file.compressedSize)
  -- print(file.compressionMethod)
  local fileContentsPtr = contents
                        + cd.fileHeaderOffset
                        + ffi.sizeof(FileEntry)
                        + file.fileNameLength
                        + file.extraFieldLength

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
  print(uncompressed)
  ffi.C.inflateEnd(stream)
end

-- local fileName = 'conf.lua'

-- local fileEntry = FileEntry()
-- fileEntry.header = 0x04034B50
-- fileEntry.minVersion = 788
-- fileEntry.generalFlag = 0
-- fileEntry.compressionMethod = 8
-- fileEntry.lastModifiedTime = 32898      -- 0x8280
-- fileEntry.lastModifiedData = 19180      -- 0xEC4A
-- fileEntry.crc32 = 3002184697            -- 0xF9B3F1B2
-- fileEntry.compressedSize = 893          -- 0x7D030000
-- fileEntry.uncompressedSize = 3262       -- 0xBE0C0000
-- fileEntry.fileNameLength = #fileName    -- 0x0800
-- fileEntry.extraFieldLength = 0          -- 0x0
-- fileEntry.fileName = fileName           -- 0x636F6E66 2E6C7561

-- local size = ffi.sizeof(FileEntry) - ffi.sizeof('uint8_t *')

-- io.output('test.zip')
-- io.write(ffi.string(fileEntry, size))
-- io.write(fileName)
-- io.write(love.math.compress(conf, 'zlib'):getString())

-- -- function love.load(args)
-- --   print('test')
-- -- end

-- local cd = CentralDirectory()
-- cd.header = 0x02014b50


-- local eocd = EOCD()
-- eocd.header = 0x06054B50
-- eocd.numberOfDisk = 0
-- eocd.diskWhereCentralDir = 0
-- eocd.numberCentralDirsOnDisk = 2
-- eocd.totalCentralDirs = 2
-- eocd.sizeOfCentralDir = 180 -- 0xB4000000
-- eocd.offsetOfCentralDir = 1093 -- 0x45040000
-- eocd.commentLength = 0
-- eocd.comment = ''


love.event.push("quit")
function love.keypressed(key, scancode, isrepeat)
  if key == "escape" then
    love.event.push("quit")
  end
end
