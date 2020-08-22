local SHA = require("opus.crypto.sha2")

local acceptableCharacters = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"}
local acceptableCharactersLen = #acceptableCharacters
   
local password = ""

for _i = 1, 8 do
    password = password .. acceptableCharacters[math.random(acceptableCharactersLen)]
end

os.queueEvent("set_otp", SHA.compute(password))

print("Your one-time password is: " .. password)