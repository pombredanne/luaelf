-------------------------------------------------------------------------------
-- ELF header object

module( ..., package.seeall )

local elfutils = require "elfutils"
local cl = require "classes"
local sb = string.byte
local ct = require "elfct"
local sf = string.format 

---------------------------------------
-- ELF Header constants

local _elfh = cl.new_class( "elfhdr", "object", "ELF header data" )

new = function( stream )
  local self = cl.new_instance( "elfhdr" )
  self.stream = stream
  return self
end

_elfh._loadident = function( self, data )  
  -- Check header
  if data[ ct.EI_MAG0 ] ~= 0x7f or data[ ct.EI_MAG1 ] ~= sb( 'E' ) or data[ ct.EI_MAG2 ] ~= sb( 'L' ) or data[ ct.EI_MAG3 ] ~= sb( 'F' ) then
    error "invalid ELF header"
  end
  -- Get class
  if data[ ct.EI_CLASS ] ~= ct.ELFCLASS32 then error "only 32-bit ELF files are supported" end
  -- Get endianness
  if data[ ct.EI_DATA ] == ct.ELFDATANONE then error "invalid data encoding in ELF header" end
  self.endian = data[ ct.EI_DATA ] == ct.ELFDATA2LSB and "little" or "big"
  self.stream:set_endianness( self.endian )
  self.osabi = data[ ct.EI_OSABI ]
  self.abiversion = data[ ct.EI_ABIVERSION ]
  -- Check version
  if data[ ct.EI_VERSION ] ~= ct.EV_CURRENT then error "invalid ELF version in ident data" end
end

_elfh.load = function( self )
  self.stream:seek( 0 )
  local s = self.stream:read( ct.EI_NIDENT )
  assert( #s == ct.EI_NIDENT )
  local data = elfutils.str2array( s, 0 )
  -- First interpret ident data
  self:_loadident( data )
  -- Then the rest of the header
  local tmp = self.stream:read_elf32_half()
  if not ct.elf_type_to_str( tmp ) then error "invalid ELF type" end
  self.e_type = tmp
  self.e_machine = self.stream:read_elf32_half()
  tmp = self.stream:read_elf32_word()
  if tmp ~= ct.EV_CURRENT then error "invalid ELF version in header" end
  self.e_entry = self.stream:read_elf32_addr()
  self.e_phoff = self.stream:read_elf32_off()
  self.e_shoff = self.stream:read_elf32_off()
  self.e_flags = self.stream:read_elf32_word()
  self.e_ehsize = self.stream:read_elf32_half()
  self.e_phentsize = self.stream:read_elf32_half()
  self.e_phnum = self.stream:read_elf32_half()
  self.e_shentsize = self.stream:read_elf32_half()
  self.e_shnum = self.stream:read_elf32_half()
  self.e_shstrndx = self.stream:read_elf32_half()
  return self
end

_elfh.get_type_str = function( self )
  return ct.elf_type_to_str( self.e_type )
end

elfutils.generate_accessors( _elfh, {
  { "entry", "e_entry" },
  { "flags", "e_flags" },
  { "num_segments", "e_phnum" },
  { "num_sections", "e_shnum" },
  { "header_size", "e_ehsize" },
  { "machine", "e_machine" },
  { "machine_str", "e_machine", ct.elf_machine_map },
  { "type", "e_type" },
  { "endianness", "endian" },
  { "string_section_index", "e_shstrndx" },
  { "sh_off", "e_shoff" },
  { "shent_size", "e_shentsize" },
  { "strtab_index", "e_shstrndx" },
  { "osabi", "osabi" },
  { "osabi_str", "osabi", ct.elf_osabi_map },
  { "abi_version", "abiversion" }
} )
