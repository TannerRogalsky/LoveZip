# LoveZip
An implementation of the Zip File Format in Lua.

It's made to work with Love but it should be trivially adaptable to work in any environment with LuaJIT's FFI and the ZLib library.

## Usage
Building a Zip file is done by instantiating the required module and then calling `:add(filename, contents)`. When satisfied that all entries have been added, calling `:compress` will return a string represeting the compressed file. It can then be written to whatever output you choose.

Decompressing a Zip file is done by reading the file from any source and calling the factory function `.decompress`. It will return a Zip file with uncompressed entries.

An instantiated Zip file has one property, `entries`, which is a map of filename's to uncompressed contents.

```lua
local Zip = require('index')

local function list_all(list, directory)
  local lfs = love.filesystem
  for index,filename in ipairs(lfs.getDirectoryItems(directory)) do
    if filename:sub(1, 1) ~= '.' then
      local file = directory .. "/" .. filename
      if lfs.isDirectory(file) then
        list_all(list, file)
      else
        table.insert(list, file)
      end
    end
  end
  return list
end

local files = list_all({}, 'test')
local output_name = 'test1.zip'

local zip = Zip()
for i,file in ipairs(files) do
  local contents = love.filesystem.read(file)
  zip:add(file, contents)
end
local compressed = zip:compress() -- equivalent to `tostring(zip)`
love.filesystem.write(output_name, compressed)

local contents, size = love.filesystem.read(output_name)
local zip2 = Zip.decompress(contents)
for i,file in ipairs(files) do
  assert(zip2.entries[file], 'Missing ' .. file)
end
```
