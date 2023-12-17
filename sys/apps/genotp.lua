local SHA = require("opus.crypto.sha2")

local acceptableCharacters = {}
for c = 0, 127 do
  local char = string.char(c)
  -- exclude potentially ambiguous characters
  if char:match("[1-9a-zA-Z]") and char:match("[^OIl]") then
    table.insert(acceptableCharacters, char)
  end
end
local acceptableCharactersLen = #acceptableCharacters
local password = ""

for i = 1, 10 do
    password = password .. acceptableCharacters[math.random(acceptableCharactersLen)]
end

os.queueEvent("set_otp", SHA.compute(password))

print("This allows one other device to permanently gain access to this device.")
print("Use the trust settings in System to revert this.")
print("Your one-time password is: " .. password)
