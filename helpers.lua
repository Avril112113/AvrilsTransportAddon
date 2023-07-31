DT = 1/60



---
---Raises an error if the value of its argument v is false (i.e., `nil` or `false`); otherwise, returns all its arguments. In case of error, `message` is the error object; when absent, it defaults to `"assertion failed!"`
---
---[View documents](command:extension.lua.doc?["en-us/53/manual.html/pdf-assert"])
---
---@generic T
---@param v? T
---@param message? any
---@return T
---@return any ...
function assert(v, message, ...)
	if not v then
		error(message or "assertion failed!")
	end
	return v, message, ...
end


--- NOTE: Based of LifeBoatAPI's lb_tostring
--- Converts the given value t, to a string, regardless of what type of value it is 
--- Doesn't handle self-referential tables (e.g. a = {}; a.b=a)
---@param t any
---@param indent nil|number
---@return string
function toStringRepr(t, maxdepth, indent, seen)
	seen = seen or {}
	indent = (indent or 0) + 1
	maxdepth = maxdepth or math.maxinteger

	local typeof = type(t)
	if typeof == "table" then
		local existing = seen[t]
		if existing then
			return "{REF-"..tostring(t).."}"
		elseif indent > (maxdepth+1) then
			return "{"..tostring(t).."}"
		else
			seen[t] = true

			local s = {}
			for k,v in pairs(t) do
				local kType = type(k)
				if kType == "string" then
					s[#s+1] = string.rep(" ", indent*4) .. "" .. tostring(k) .. " = " .. toStringRepr(v, maxdepth, indent, seen)
				elseif kType ~= "number" or (k < 1 or k > #t) then
					s[#s+1] = string.rep(" ", indent*4) .. "[" .. tostring(k) .. "] = " .. toStringRepr(v, maxdepth, indent, seen)
				end
				-- don't print numbers, do numericals below
			end

			for i=1,#t do
				s[#s+1] = string.rep(" ", indent*4) .. toStringRepr(t[i], maxdepth, indent, seen)
			end
			if #s > 0 then
				return "{<"..tostring(t)..">\n" .. table.concat(s, ",\n") .. "\n" .. string.rep(" ", (indent-1)*4) .. "}"
			else
				return "{<"..tostring(t)..">}"
			end
		end
    elseif typeof == "string" then
        return "\"" .. t .. "\""
	else
		return tostring(t)
	end
end


---@param source table
---@param dest table?
function shallowCopy(source, dest)
	dest = dest or {}
	for i, v in pairs(source) do
		dest[i] = v
	end
	return dest
end

---@generic T : table?
---@param source T
---@param dest T
---@return T
function simpleDeepCopy(source, dest)
	if source == nil then
		return nil
	end
	dest = dest or {}
	for i, v in pairs(source) do
		if type(v) == "table" then
			v = simpleDeepCopy(v, dest[i] or {})
		end
		dest[i] = v
	end
	return dest
end

local TRUTHY_VALUES = {t=true, tr=true, tru=true, ["true"]=true, y=true, ye=true, yes=true}
---@param s string|nil
function arg_truthy(s)
	return s ~= nil and TRUTHY_VALUES[s:lower()] or false
end


---@param seconds number
---@return string
function fmtRate(seconds)
	local hours = 0
	local days = 0
	if seconds >= 60 then
		hours = seconds // 60
		seconds = seconds - hours*60
		if hours >= 24 then
			days = hours // 24
			hours = hours - hours*24
		end
	end
	local parts = {("%.0fs"):format(seconds)}
	if hours > 0 then
		table.insert(parts, ("%.0fh"):format(hours))
	end
	if days > 0 then
		table.insert(parts, ("%.0fdays"):format(days))
	end
	return table.concat(parts, " ")
end

---@param value number
---@param decimals integer
function round(value, decimals)
	return tonumber(string.format("%."..(decimals//1).."f", value))
end
