function love.draw()
  love.graphics.print("hello world")
end

function love.keypressed(key, scancode, isrepeat)
  if key == "escape" then
    love.event.push("quit")
  end
end
