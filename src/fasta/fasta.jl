# FASTA File Format
# =================

module FASTA

import Automa
import Automa.RegExp: @re_str
import Automa.Stream: @mark, @markpos, @relpos, @abspos
import BioGenerics: BioGenerics, isfilled
import BioGenerics.Exceptions: missingerror
import BioGenerics.Automa: State
import BioSequences
import BioSymbols
import TranscodingStreams: TranscodingStreams, TranscodingStream
import ..FASTX: identifier, description, sequence

include("record.jl")
include("index.jl")
include("readrecord.jl")
include("reader.jl")
include("writer.jl")

end
