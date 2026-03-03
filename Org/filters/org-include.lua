local io = require("io")

function RawBlock(el)
  local path = el.text:match('^#%+(?:INCLUDE|SETUPFILE):%s*["\']?([^"\']+)["\']?')

  if path then
    local file = io.open(path, "rb")

    if not file then
      print("Warning: Could not find file: " .. path)
      return el
    end

    local content = file:read("*all")
    file:close()

    return pandoc.read(content, "org").blocks
  end

  return el
end
