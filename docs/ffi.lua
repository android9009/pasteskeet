---@meta
-- IDE declarations for the bundled cffi-lua module. Do not run as a script.
-- See FFI.ru.md for loading, ownership, callback threading and native limits.
---@class CData
---@class CType
---@class CCallback: CData
---@field free fun(self: CCallback)
---@field set fun(self: CCallback, callback: function)
---@class CLibrary
---@class FFI
---@field C CLibrary
---@field os string
---@field arch string
---@field nullptr CData
---@type FFI
ffi = {}
---@param declarations string
function ffi.cdef(declarations, ...) end
---@param name string UTF-8 DLL name/path on Windows.
---@param global? boolean
---@return CLibrary
function ffi.load(name, global) end
---@param ctype string|CType
---@return CData
function ffi.new(ctype, ...) end
---@param ctype string|CType
---@return CType
function ffi.typeof(ctype, ...) end
---@param ctype string|CType
---@param value any
---@return CData
function ffi.cast(ctype, value) end
---@param ctype string|CType
---@param metatable table
---@return CType
function ffi.metatype(ctype, metatable) end
---@param value CData
---@return CData pointer
function ffi.addressof(value) end
---@param value CData
---@param finalizer? fun(value: CData) nil removes finalizer.
---@return CData
function ffi.gc(value, finalizer) end
---@param value CData
---@param length? integer
---@return string
function ffi.string(value, length) end
---@param value CData|string|CType
---@return integer? nil when size is unknown.
function ffi.sizeof(value, ...) end
---@param value CData|string|CType
---@return integer
function ffi.alignof(value) end
---@param ctype string|CType
---@param field string
---@return integer?
function ffi.offsetof(ctype, field) end
---@param destination CData
---@param source CData|string
---@param length? integer
function ffi.copy(destination, source, length) end
---@param destination CData
---@param length integer
---@param byte? integer
function ffi.fill(destination, length, byte) end
---@param ctype string|CType
---@param value CData
---@return boolean
function ffi.istype(ctype, value) end
---@param flag string
---@return boolean
function ffi.abi(flag) end
---@param value? integer
---@return integer
function ffi.errno(value) end
---@param value CData|number|string
---@return number?
function ffi.tonumber(value) end
---@param value CData
---@return any
function ffi.toretval(value) end
---@param literal string Numeric literal; not a C expression evaluator.
---@return CData
function ffi.eval(literal) end
---@param value any
---@return string 'cdata' for CData/CType, otherwise the ordinary Lua type.
function ffi.type(value) end
