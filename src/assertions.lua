-- module will not return anything, only register assertions with the main assert engine

-- assertions take 2 parameters;
-- 1) state
-- 2) arguments list. The list has a member 'n' with the argument count to check for trailing nils
-- returns; boolean; whether assertion passed

local assert = require('luassert.assert')
local astate = require ('luassert.state')
local util = require ('luassert.util')
local s = require('say')

local function format(val)
  return astate.format_argument(val) or tostring(val)
end

local function unique(state, arguments)
  local list = arguments[1]
  local deep
  local argcnt = arguments.n
  if type(arguments[2]) == "boolean" or (arguments[2] == nil and argcnt > 2) then
    deep = arguments[2]
    state.failure_message = arguments[3] or rawget(state, "failure_message")
  else
    if type(arguments[3]) == "boolean" then
      deep = arguments[3]
    end
    state.failure_message = arguments[2] or rawget(state, "failure_message")
  end
  for k,v in pairs(list) do
    for k2, v2 in pairs(list) do
      if k ~= k2 then
        if deep and util.deepcompare(v, v2, true) then
          return false
        else
          if v == v2 then
            return false
          end
        end
      end
    end
  end
  return true
end

local function near(state, arguments)
  local argcnt = arguments.n
  assert(argcnt > 2, s("assertion.internal.argtolittle", { "near", 3, tostring(argcnt) }))
  local expected = tonumber(arguments[1])
  local actual = tonumber(arguments[2])
  local tolerance = tonumber(arguments[3])
  local numbertype = "number or object convertible to a number"
  assert(expected, s("assertion.internal.badargtype", { "near", numbertype, format(arguments[1]) }))
  assert(actual, s("assertion.internal.badargtype", { "near", numbertype, format(arguments[2]) }))
  assert(tolerance, s("assertion.internal.badargtype", { "near", numbertype, format(arguments[3]) }))
  -- switch arguments for proper output message
  util.tinsert(arguments, 1, util.tremove(arguments, 2))
  arguments[3] = tolerance
  arguments.nofmt = arguments.nofmt or {}
  arguments.nofmt[3] = true
  state.failure_message = arguments[4] or rawget(state, "failure_message")
  return (actual >= expected - tolerance and actual <= expected + tolerance)
end

local function matches(state, arguments)
  local argcnt = arguments.n
  assert(argcnt > 1, s("assertion.internal.argtolittle", { "matches", 2, tostring(argcnt) }))
  local pattern = arguments[1]
  local actual = nil
  if util.hastostring(arguments[2]) or type(arguments[2]) == "number" then
    actual = tostring(arguments[2])
  end
  local err_message
  for i=3,argcnt,1 do
    if util.hastostring(arguments[i]) and not tonumber(arguments[i]) then
      err_message = util.tremove(arguments, i)
      break
    end
  end
  local init = arguments[3]
  local plain = arguments[4]
  local stringtype = "string or object convertible to a string"
  assert(type(pattern) == "string", s("assertion.internal.badargtype", { "matches", "string", type(arguments[1]) }))
  assert(actual, s("assertion.internal.badargtype", { "matches", stringtype, format(arguments[2]) }))
  assert(init == nil or tonumber(init), s("assertion.internal.badargtype", { "matches", "number", type(arguments[3]) }))
  -- switch arguments for proper output message
  util.tinsert(arguments, 1, util.tremove(arguments, 2))
  state.failure_message = err_message or rawget(state, "failure_message")
  return (actual:find(pattern, init, plain) ~= nil)
end

local function equals(state, arguments)
  local argcnt = arguments.n
  assert(argcnt > 1, s("assertion.internal.argtolittle", { "equals", 2, tostring(argcnt) }))
  local result =  arguments[1] == arguments[2]
  -- switch arguments for proper output message
  util.tinsert(arguments, 1, util.tremove(arguments, 2))
  state.failure_message = arguments[3] or rawget(state, "failure_message")
  return result
end

local function same(state, arguments)
  local argcnt = arguments.n
  assert(argcnt > 1, s("assertion.internal.argtolittle", { "same", 2, tostring(argcnt) }))
  if type(arguments[1]) == 'table' and type(arguments[2]) == 'table' then
    local result, crumbs = util.deepcompare(arguments[1], arguments[2], true)
    -- switch arguments for proper output message
    util.tinsert(arguments, 1, util.tremove(arguments, 2))
    arguments.fmtargs = arguments.fmtargs or {}
    arguments.fmtargs[1] = { crumbs = crumbs }
    arguments.fmtargs[2] = { crumbs = crumbs }
    state.failure_message = arguments[3] or rawget(state, "failure_message")
    return result
  end
  local result = arguments[1] == arguments[2]
  -- switch arguments for proper output message
  util.tinsert(arguments, 1, util.tremove(arguments, 2))
  state.failure_message = arguments[3] or rawget(state, "failure_message")
  return result
end

local function truthy(state, arguments)
  state.failure_message = arguments[2] or rawget(state, "failure_message")
  return arguments[1] ~= false and arguments[1] ~= nil
end

local function falsy(state, arguments)
  return not truthy(state, arguments)
end

local function has_error(state, arguments)
  local func = arguments[1]
  local err_expected = arguments[2]
  local failure_message = arguments[3]
  assert(util.callable(func), s("assertion.internal.badargtype", { "error", "function, or callable object", type(func) }))
  local ok, err_actual = pcall(func)
  if type(err_actual) == 'string' then
    -- remove 'path/to/file:line: ' from string
    err_actual = err_actual:gsub('^.-:%d+: ', '', 1)
  end
  arguments.nofmt = {}
  arguments.n = 2
  arguments[1] = (ok and '(no error)' or err_actual)
  arguments[2] = (err_expected == nil and '(error)' or err_expected)
  arguments.nofmt[1] = ok
  arguments.nofmt[2] = (err_expected == nil)
  state.failure_message = failure_message or rawget(state, "failure_message")

  if ok or err_expected == nil then
    return not ok
  end
  if type(err_expected) == 'string' then
    -- err_actual must be (convertible to) a string
    if util.hastostring(err_actual) then
      err_actual = tostring(err_actual)
    end
    if type(err_actual) == 'string' then
      return err_expected == err_actual
    end
  elseif type(err_expected) == 'number' then
    if type(err_actual) == 'string' then
      return tostring(err_expected) == tostring(tonumber(err_actual))
    end
  end
  return same(state, {err_expected, err_actual, ["n"] = 2})
end

local function is_true(state, arguments)
  util.tinsert(arguments, 2, true)
  state.failure_message = arguments[3] or rawget(state, "failure_message")
  return arguments[1] == arguments[2]
end

local function is_false(state, arguments)
  util.tinsert(arguments, 2, false)
  state.failure_message = arguments[3] or rawget(state, "failure_message")
  return arguments[1] == arguments[2]
end

local function is_type(state, arguments, etype)
  util.tinsert(arguments, 2, "type " .. etype)
  arguments.nofmt = arguments.nofmt or {}
  arguments.nofmt[2] = true
  state.failure_message = arguments[3] or rawget(state, "failure_message")
  return arguments.n > 1 and type(arguments[1]) == etype
end

local function returned_arguments(state, arguments)
  arguments[1] = tostring(arguments[1])
  arguments[2] = tostring(arguments.n - 1)
  arguments.nofmt = arguments.nofmt or {}
  arguments.nofmt[1] = true
  arguments.nofmt[2] = true
  if arguments.n < 2 then arguments.n = 2 end
  return arguments[1] == arguments[2]
end

local function set_message(state, arguments)
  state.failure_message = arguments[1]
end

local function is_boolean(state, arguments)  return is_type(state, arguments, "boolean")  end
local function is_number(state, arguments)   return is_type(state, arguments, "number")   end
local function is_string(state, arguments)   return is_type(state, arguments, "string")   end
local function is_table(state, arguments)    return is_type(state, arguments, "table")    end
local function is_nil(state, arguments)      return is_type(state, arguments, "nil")      end
local function is_userdata(state, arguments) return is_type(state, arguments, "userdata") end
local function is_function(state, arguments) return is_type(state, arguments, "function") end
local function is_thread(state, arguments)   return is_type(state, arguments, "thread")   end

assert:register("modifier", "message", set_message)
assert:register("assertion", "true", is_true, "assertion.same.positive", "assertion.same.negative")
assert:register("assertion", "false", is_false, "assertion.same.positive", "assertion.same.negative")
assert:register("assertion", "boolean", is_boolean, "assertion.same.positive", "assertion.same.negative")
assert:register("assertion", "number", is_number, "assertion.same.positive", "assertion.same.negative")
assert:register("assertion", "string", is_string, "assertion.same.positive", "assertion.same.negative")
assert:register("assertion", "table", is_table, "assertion.same.positive", "assertion.same.negative")
assert:register("assertion", "nil", is_nil, "assertion.same.positive", "assertion.same.negative")
assert:register("assertion", "userdata", is_userdata, "assertion.same.positive", "assertion.same.negative")
assert:register("assertion", "function", is_function, "assertion.same.positive", "assertion.same.negative")
assert:register("assertion", "thread", is_thread, "assertion.same.positive", "assertion.same.negative")
assert:register("assertion", "returned_arguments", returned_arguments, "assertion.returned_arguments.positive", "assertion.returned_arguments.negative")

assert:register("assertion", "same", same, "assertion.same.positive", "assertion.same.negative")
assert:register("assertion", "matches", matches, "assertion.matches.positive", "assertion.matches.negative")
assert:register("assertion", "match", matches, "assertion.matches.positive", "assertion.matches.negative")
assert:register("assertion", "near", near, "assertion.near.positive", "assertion.near.negative")
assert:register("assertion", "equals", equals, "assertion.equals.positive", "assertion.equals.negative")
assert:register("assertion", "equal", equals, "assertion.equals.positive", "assertion.equals.negative")
assert:register("assertion", "unique", unique, "assertion.unique.positive", "assertion.unique.negative")
assert:register("assertion", "error", has_error, "assertion.error.positive", "assertion.error.negative")
assert:register("assertion", "errors", has_error, "assertion.error.positive", "assertion.error.negative")
assert:register("assertion", "truthy", truthy, "assertion.truthy.positive", "assertion.truthy.negative")
assert:register("assertion", "falsy", falsy, "assertion.falsy.positive", "assertion.falsy.negative")
