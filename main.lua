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
local compressed = zip:compress()
love.filesystem.write(output_name, compressed)

local contents, size = love.filesystem.read(output_name)
local zip2 = Zip.decompress(contents)
for i,file in ipairs(files) do
  assert(zip2.entries[file], 'Missing ' .. file)
end

love.event.push("quit")
