# frozen_string_literal: true

module HTS
  module LibHTS
    # Open the named file or URL as a stream
    attach_function \
      :hopen,
      %i[string string varargs],
      HFILE.by_ref

    # Associate a stream with an existing open file descriptor
    attach_function \
      :hdopen,
      %i[int string],
      HFILE.by_ref

    # Report whether the file name or URL denotes remote storage
    attach_function \
      :hisremote,
      [:string],
      :int

    # Append an extension or replace an existing extension
    attach_function \
      :haddextension,
      [KString, :string, :int, :string],
      :string

    # Flush (for output streams) and close the stream
    attach_function \
      :hclose,
      [HFILE],
      :int

    # Close the stream, without flushing or propagating errors
    attach_function \
      :hclose_abruptly,
      [HFILE],
      :void

    # Reposition the read/write stream offset
    attach_function \
      :hseek,
      [HFILE, :off_t, :int],
      :off_t

    # Report the current stream offset
    def self.htell(fp)
      # TODO: This is a hack. Is this OK?
      bg = FFI::Pointer.new(:int, fp.pointer.address + fp.offset_of(:begin)).read_int
      bf = FFI::Pointer.new(:int, fp.pointer.address + fp.offset_of(:buffer)).read_int
      fp[:offset] + (bg - bf)
    end

    # Read from the stream until the delimiter, up to a maximum length
    attach_function \
      :hgetdelim,
      [:string, :size_t, :int, HFILE],
      :ssize_t

    # Read a line from the stream, up to a maximum length
    attach_function \
      :hgets,
      [:string, :int, HFILE],
      :string

    # Peek at characters to be read without removing them from buffers
    attach_function \
      :hpeek,
      [HFILE, :pointer, :size_t],
      :ssize_t

    # For writing streams, flush buffered output to the underlying stream
    attach_function \
      :hflush,
      [HFILE],
      :int

    # For hfile_mem: get the internal buffer and it's size from a hfile
    attach_function \
      :hfile_mem_get_buffer,
      [HFILE, :pointer],
      :string

    # For hfile_mem: get the internal buffer and it's size from a hfile.
    attach_function \
      :hfile_mem_steal_buffer,
      [HFILE, :pointer],
      :string
    
    # Fills out sc_list[] with the list of known URL schemes.
    attach_function \
      :hfile_list_schemes,
      [:string, :pointer, :pointer], # mutable string
      :int

    # Fills out plist[] with the list of known hFILE plugins.
    attach_function \
      :hfile_list_plugins,
      [:pointer, :pointer], # mutable string
      :int

    # Tests for the presence of a specific hFILE plugin.
    attach_function \
      :hfile_has_plugin,
      [:string],
      :int
  end
end
