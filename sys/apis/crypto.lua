-- https://github.com/PixelToast/ComputerCraft/blob/master/apis/enc

local Crypto = { }

local function serialize(t) 
	local sType = type(t)
	if sType == "table" then
		local lstcnt=0
		for k,v in pairs(t) do
			lstcnt = lstcnt + 1
		end
		local result = "{"
		local aset=1
		for k,v in pairs(t) do
			if k==aset then
				result = result..serialize(v)..","
				aset=aset+1
			else
				result = result..("["..serialize(k).."]="..serialize(v)..",")
			end
		end
		result = result.."}"
		return result
	elseif sType == "string" then
		return string.format("%q",t)
	elseif sType == "number" or sType == "boolean" or sType == "nil" then
		return tostring(t)
	elseif sType == "function" then
		local status,data=pcall(string.dump,t)
		if status then
			data2=""
			for char in string.gmatch(data,".") do
				data2=data2..zfill(string.byte(char))
			end
			return 'f("'..data2..'")'
		else
			error("Invalid function: "..data)
		end
	else
		error("Could not serialize type "..sType..".")
	end
end

local function unserialize( s )
	local func, e = loadstring( "return "..s, "serialize" )
	if not func then
		return s,e
	else
		setfenv( func, {
			f=function(S)
				return loadstring(splitnum(S))
			end,
		})
		return func()
	end
end

local function splitnum(S)
	local Out=""
	for l1=1,#S,2 do
		local l2=(#S-l1)+1
		local function sure(N,n)
			if (l2-n)<1 then N="0" end
			return N
		end
		local CNum=tonumber("0x"..sure(string.sub(S,l2-1,l2-1),1) .. sure(string.sub(S,l2,l2),0))
		Out=string.char(CNum)..Out
	end
	return Out
end

local function zfill(N)
	N=string.format("%X",N)
	Zs=""
	if #N==1 then
		Zs="0"
	end
	return Zs..N
end

local function wrap(N)
	return N-(math.floor(N/256)*256)
end

local function checksum(S)
	local sum=0
	for char in string.gmatch(S,".") do
		math.randomseed(string.byte(char)+sum)
		sum=sum+math.random(0,9999)
	end
	math.randomseed(sum)
	return sum
end

local function genkey(len,psw)
	checksum(psw)
	local key={}
	local tKeys={}
	for l1=1,len do
		local num=math.random(1,len)
		while tKeys[num] do
			num=math.random(1,len)
		end
		tKeys[num]=true
		key[l1]={num,math.random(0,255)}
	end
	return key
end

function Crypto.encrypt(data,psw)
	data=serialize(data)
	local chs=checksum(data)
	local key=genkey(#data,psw)
	local out={}
	local cnt=1
	for char in string.gmatch(data,".") do
		table.insert(out,key[cnt][1],zfill(wrap(string.byte(char)+key[cnt][2])),chars)
		cnt=cnt+1
	end
	return string.sub(serialize({chs,table.concat(out)}),2,-3)
end

function Crypto.decrypt(data,psw)
	local oData=data
	data=unserialize("{"..data.."}")
	if type(data)~="table" then
		return oData
	end
	local chs=data[1]
	data=data[2]
	local key=genkey((#data)/2,psw)
	local sKey={}
	for k,v in pairs(key) do
		sKey[v[1]]={k,v[2]}
	end
	local str=splitnum(data)
	local cnt=1
	local out={}
	for char in string.gmatch(str,".") do
		table.insert(out,sKey[cnt][1],string.char(wrap(string.byte(char)-sKey[cnt][2])))
		cnt=cnt+1
	end
	out=table.concat(out)
	if checksum(out or "")==chs then
		return unserialize(out)
	end
	return oData,out,chs
end

return Crypto
