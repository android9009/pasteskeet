-- Manual probe after the user's build. No native DLL is executed by offline tests.
local ffi = require("ffi")
assert(ffi == require("cffi"))
ffi.cdef[[
    unsigned long __stdcall GetCurrentProcessId(void);
    struct skeet_ffi_probe { uint32_t value; uint8_t bytes[4]; };
]]
local kernel = ffi.load("kernel32")
assert(tonumber(kernel.GetCurrentProcessId()) > 0)
local probe = ffi.new("struct skeet_ffi_probe")
probe.value = 123
probe.bytes[0] = 65
probe.bytes[1] = 66
assert(tonumber(probe.value) == 123)
assert(ffi.sizeof(probe) == 8)
assert(ffi.string(probe.bytes, 2) == "AB")
local pixels = string.rep(string.char(40, 130, 220, 255), 64 * 64)
local texture
events.on("paint", function()
    if not texture then texture = assert(render.create_texture_rgba(64, 64)) end
    assert(render.update_texture_rgba(texture, pixels))
    render.texture(texture, 50, 50, 128, 128)
end)
client.log("FFI smoke: native call, cdef, struct, array and string passed; check blue texture")
