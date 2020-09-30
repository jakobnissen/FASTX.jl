using Test
using FASTX
using FormatSpecimens
import BioGenerics
import BioGenerics.Testing: intempdir
import BioSequences:
    @dna_str,
    @rna_str,
    @aa_str,
    LongDNASeq,
    LongAminoAcidSeq,
    LongSequence,
    DNAAlphabet,
    DNA_N,
    DNA_A,
    DNA_G

@testset "FASTA" begin
    @testset "Record" begin
        record = FASTA.Record()
        @test !BioGenerics.isfilled(record)
        @test_throws ArgumentError FASTA.identifier(record)
        @test_throws ArgumentError FASTA.description(record)
        @test_throws ArgumentError FASTA.sequence(record)

        record = FASTA.Record(">foo\nACGT\n")
        @test BioGenerics.isfilled(record)
        @test BioGenerics.hasseqname(record)
        @test FASTA.hasidentifier(record)
        @test BioGenerics.seqname(record) == FASTA.identifier(record) == "foo"
        @test !FASTA.hasdescription(record)
        @test FASTA.description(record) === nothing
        @test BioGenerics.hassequence(record)
        @test FASTA.hassequence(record)
        @test FASTA.sequence(record) == dna"ACGT"
        @test FASTA.sequence(record, 2:3) == dna"CG"
        @test FASTA.sequence(String, record) == "ACGT"
        @test FASTA.sequence(String, record, 2:3) == "CG"

        record1 = FASTA.Record("id", "desc", "AGCT")
        record2 = FASTA.Record("id", "desc", "AGCT")
        @test record1 == record2
        @test hash(record1) == hash(record2)
        @test unique([record1, record1, record2, record2]) == [record1] == [record2]

        record1 = FASTA.Record("id", "AGCT")
        record2 = FASTA.Record("id", "AGCT")
        @test record1 == record2
        @test FASTA.Record() == FASTA.Record()
        @test FASTA.Record() != record1
        @test hash(record1) == hash(record2)
        @test unique([record1, record1, record2, record2]) == [record1] == [record2]

        @test FASTA.Record("id", "AGCT") != FASTA.Record("id2", "AGCT")
        @test FASTA.Record("id", "AGCT") != FASTA.Record("id", "TAGC")
        @test FASTA.Record("id", "desc", "AGCT") != FASTA.Record("id", "AGCT")
        @test FASTA.Record("id", "desc", "AGCT") != FASTA.Record("id", "desc", "TAGC")
        @test FASTA.Record("id", "desc", "AGCT") != FASTA.Record("id", "desc2", "AGCT")

        @test hash(FASTA.Record("id", "AGCT")) != hash(FASTA.Record("id2", "AGCT"))
        @test hash(FASTA.Record("id", "AGCT")) != hash(FASTA.Record("id", "TAGC"))
        @test hash(FASTA.Record("id", "desc", "AGCT")) != hash(FASTA.Record("id", "AGCT"))
        @test hash(FASTA.Record("id", "desc", "AGCT")) != hash(FASTA.Record("id", "desc", "TAGC"))
        @test hash(FASTA.Record("id", "desc", "AGCT")) != hash(FASTA.Record("id", "desc2", "AGCT"))

        record = FASTA.Record("""
        >CYS1_DICDI fragment
        SCWSFSTTGNVEGQHFISQNKL
        VSLSEQNLVDCDHECMEYEGE
        """)
        @test BioGenerics.isfilled(record)
        @test FASTA.identifier(record) == "CYS1_DICDI"
        @test FASTA.description(record) == "fragment"
        @test FASTA.header(record, "__") == "CYS1_DICDI__fragment"
        @test FASTA.sequence(record) == aa"SCWSFSTTGNVEGQHFISQNKLVSLSEQNLVDCDHECMEYEGE"
        @test FASTA.sequence(record, 10:15) == aa"NVEGQH"
    end

    output = IOBuffer()
    writer = FASTA.Writer(output, 5)
    write(writer, FASTA.Record("seq1", dna"TTA"))
    write(writer, FASTA.Record("seq2", "some description", dna"ACGTNN"))
    flush(writer)
    @test String(take!(output)) == """
    >seq1
    TTA
    >seq2 some description
    ACGTN
    N
    """

    reader = FASTA.Reader(IOBuffer(
    """
    >seqA some description
    QIKDLLVSSSTDLDTTLKMK
    ILELPFASGDLSM
    >seqB
    VLMALGMTDLFIPSANLTG*
    """))
    record = FASTA.Record()
    @test read!(reader, record) === record
    @test FASTA.identifier(record) == "seqA"
    @test FASTA.description(record) == "some description"
    @test FASTA.header(record, '@') == "seqA@some description"
    @test FASTA.sequence(record) == aa"QIKDLLVSSSTDLDTTLKMKILELPFASGDLSM"
    @test copyto!(LongAminoAcidSeq(FASTA.seqlen(record)), record) == aa"QIKDLLVSSSTDLDTTLKMKILELPFASGDLSM"
    @test read!(reader, record) === record
    @test FASTA.identifier(record) == "seqB"
    @test !FASTA.hasdescription(record)
    @test FASTA.sequence(record) == aa"VLMALGMTDLFIPSANLTG*"
    @test copyto!(LongAminoAcidSeq(FASTA.seqlen(record)), record) == aa"VLMALGMTDLFIPSANLTG*"
    @test_throws ArgumentError copyto!(LongAminoAcidSeq(10), FASTA.Record())

    function test_fasta_parse(filename, valid)
        filepath = joinpath(path_of_format("FASTA"), filename)
        # Reading from a stream
        stream = open(FASTA.Reader, filepath)
        @test eltype(stream) == FASTA.Record
        if valid
            for seqrec in stream end
            @test true  # no error
            @test close(stream) === nothing
        else
            @test_throws Exception begin
                for seqrec in stream end
            end
            return
        end

        # in-place parsing
        stream = open(FASTA.Reader, filepath)
        entry = eltype(stream)()
        while !eof(stream)
            read!(stream, entry)
        end

        # Check round trip
        output = IOBuffer()
        writer = FASTA.Writer(output, width = 60)
        outputB = IOBuffer()
        writerB = FASTA.Writer(outputB, width = -1)
        expected_entries = Any[]
        for seqrec in open(FASTA.Reader, filepath)
            write(writer, seqrec)
            write(writerB, seqrec)
            push!(expected_entries, seqrec)
        end
        flush(writer)
        flush(writerB)

        seekstart(output)
        seekstart(outputB)
        read_entries = FASTA.Record[]
        read_entriesB = FASTA.Record[]
        for seqrec in FASTA.Reader(output)
            push!(read_entries, seqrec)
        end
        for seqrec in FASTA.Reader(outputB)
            push!(read_entriesB, seqrec)
        end
        @test expected_entries == read_entries
        @test expected_entries == read_entriesB
    end
     
    valid_specimens = list_valid_specimens("FASTA") do specimen
        !hastag(specimen, "comments")
    end
    invalid_specimens = list_invalid_specimens("FASTA")
    for specimen in valid_specimens
        test_fasta_parse(filename(specimen), true)
    end
    for specimen in invalid_specimens
        test_fasta_parse(filename(specimen), false)
    end

    @testset "Faidx" begin
        fastastr = """
        >chr1
        CCACACCACACCCACACACC
        >chr2
        ATGCATGCATGCAT
        GCATGCATGCATGC
        >chr3
        AAATAGCCCTCATGTACGTCTCCTCCAAGCCCTGTTGTCTCTTACCCGGA
        TGTTCAACCAAAAGCTACTTACTACCTTTATTTTATGTTTACTTTTTATA
        >chr4
        TACTT
        """
        # generated with `samtools faidx`
        faistr = """
        chr1	20	6	20	21
        chr2	28	33	14	15
        chr3	100	69	50	51
        chr4	5	177	5	6
        """
        mktempdir() do dir
            filepath = joinpath(dir, "test.fa")
            write(filepath, fastastr)
            write(filepath * ".fai", faistr)
            open(FASTA.Reader, filepath, index=filepath * ".fai") do reader
                chr3 = reader["chr3"]
                @test FASTA.identifier(chr3) == "chr3"
                @test FASTA.sequence(chr3) == dna"""
                AAATAGCCCTCATGTACGTCTCCTCCAAGCCCTGTTGTCTCTTACCCGGA
                TGTTCAACCAAAAGCTACTTACTACCTTTATTTTATGTTTACTTTTTATA
                """

                chr2 = reader["chr2"]
                @test FASTA.identifier(chr2) == "chr2"
                @test FASTA.sequence(chr2) == dna"""
                ATGCATGCATGCAT
                GCATGCATGCATGC
                """

                chr4 = reader["chr4"]
                @test FASTA.identifier(chr4) == "chr4"
                @test FASTA.sequence(chr4) == dna"""
                TACTT
                """

                chr1 = reader["chr1"]
                @test FASTA.identifier(chr1) == "chr1"
                @test FASTA.sequence(chr1) == dna"""
                CCACACCACACCCACACACC
                """

                @test_throws ArgumentError reader["chr5"]
            end
        end

        # invalid index
        @test_throws ArgumentError FASTA.Reader(IOBuffer(fastastr), index=π)
    end

    @testset "append" begin
        intempdir() do
            filepath = "test.fa"
            writer = open(FASTA.Writer, filepath)
            write(writer, FASTA.Record("seq1", dna"AAA"))
            close(writer)
            writer = open(FASTA.Writer, filepath, append=true)
            write(writer, FASTA.Record("seq2", dna"CCC"))
            close(writer)
            seqs = open(collect, FASTA.Reader, filepath)
            @test length(seqs) == 2
        end
    end
end

@testset "FASTQ" begin
    @test isa(FASTQ.Record("1", dna"AA", UInt8[10, 11]), FASTQ.Record)
    @test isa(FASTQ.Record("1", "desc.", dna"AA", UInt8[10, 11]), FASTQ.Record)
    @test_throws ArgumentError FASTQ.Record("1", dna"AA", UInt8[10])

    output = IOBuffer()
    writer = FASTQ.Writer(output)
    write(writer, FASTQ.Record("1", dna"AN", UInt8[11, 25]))
    write(writer, FASTQ.Record("2", "high quality", dna"TGA", UInt8[40, 41, 45]))
    flush(writer)
    @test String(take!(output)) == """
    @1
    AN
    +
    ,:
    @2 high quality
    TGA
    +
    IJN
    """

    output = IOBuffer()
    writer = FASTQ.Writer(output, quality_header=true)
    write(writer, FASTQ.Record("1", dna"AN", UInt8[11, 25]))
    write(writer, FASTQ.Record("2", "high quality", dna"TGA", UInt8[40, 41, 45]))
    flush(writer)
    @test String(take!(output)) == """
    @1
    AN
    +1
    ,:
    @2 high quality
    TGA
    +2 high quality
    IJN
    """

    @testset "Record" begin
        record = FASTQ.Record()
        @test !BioGenerics.isfilled(record)

        record = FASTQ.Record("""
        @SRR1238088.1.1 HWI-ST499:111:D0G94ACXX:1:1101:1173:2105
        AAGCTCATGACCCGTCTTACCTACACCCTTGACGAGATCGAAGGA
        +SRR1238088.1.1 HWI-ST499:111:D0G94ACXX:1:1101:1173:2105
        @BCFFFDFHHHHHJJJIJIJJIJJJJJJJJIJJJJIIIJJJIJJJ
        """)
        
        seq = dna"AAGCTCATGACCCGTCTTACCTACACCCTTGACGAGATCGAAGGA"
        
        @test BioGenerics.isfilled(record)
        @test FASTQ.hasidentifier(record) == BioGenerics.hasseqname(record) == true
        @test FASTQ.identifier(record) == BioGenerics.seqname(record) == "SRR1238088.1.1"
        @test FASTQ.hasdescription(record)
        @test FASTQ.description(record) == "HWI-ST499:111:D0G94ACXX:1:1101:1173:2105"
        @test FASTQ.hassequence(record) == BioGenerics.hassequence(record) == true
        @test FASTQ.header(record, " ") == FASTQ.identifier(record) * " " * FASTQ.description(record)
        @test FASTQ.sequence(LongDNASeq, record) == seq
        @test copyto!(LongDNASeq(FASTQ.seqlen(record)), record) == seq
        @test_throws ArgumentError copyto!(LongDNASeq(10), FASTQ.Record())
        @test FASTQ.sequence(record) == BioGenerics.sequence(record) == seq
        @test FASTQ.sequence(String, record) == "AAGCTCATGACCCGTCTTACCTACACCCTTGACGAGATCGAAGGA"
        @test FASTQ.hasquality(record)
        @test FASTQ.quality(record) == b"@BCFFFDFHHHHHJJJIJIJJIJJJJJJJJIJJJJIIIJJJIJJJ" .- 33

        record1 = FASTQ.Record("id", "desc", "AAGCT", collect("@BCFF"))
        record2 = FASTQ.Record("id", "desc", "AAGCT", collect("@BCFF"))
        @test record1 == record2
        @test hash(record1) == hash(record2)
        @test unique([record1, record1, record2, record2]) == [record1] == [record2]

        record1 = FASTQ.Record("id", "AAGCT", collect("@BCFF"))
        record2 = FASTQ.Record("id", "AAGCT", collect("@BCFF"))
        @test record1 == record2
        @test FASTQ.Record() == FASTQ.Record()
        @test FASTQ.Record() != record1
        @test hash(record1) == hash(record2)
        @test unique([record1, record1, record2, record2]) == [record1] == [record2]

        @test FASTQ.Record("id", "AAGCT", collect("@BCFF")) != FASTQ.Record("id2", "AAGCT", collect("@BCFF"))
        @test FASTQ.Record("id", "AAGCT", collect("@BCFF")) != FASTQ.Record("id", "AGTCA", collect("@BCFF"))
        @test FASTQ.Record("id", "AAGCT", collect("@BCFF")) != FASTQ.Record("id", "AAGCT", collect("@BCFG"))
        @test FASTQ.Record("id", "desc", "AAGCT", collect("@BCFF")) != FASTQ.Record("id", "AAGCT", collect("@BCFF"))
        @test FASTQ.Record("id", "desc", "AAGCT", collect("@BCFF")) != FASTQ.Record("id", "desc", "AGTCA", collect("@BCFF"))
        @test FASTQ.Record("id", "desc", "AAGCT", collect("@BCFF")) != FASTQ.Record("id", "desc2", "AAGCT", collect("@BCFF"))

        @test hash(FASTQ.Record("id", "AAGCT", collect("@BCFF"))) != hash(FASTQ.Record("id2", "AAGCT", collect("@BCFF")))
        @test hash(FASTQ.Record("id", "AAGCT", collect("@BCFF"))) != hash(FASTQ.Record("id", "AGTCA", collect("@BCFF")))
        @test hash(FASTQ.Record("id", "AAGCT", collect("@BCFF"))) != hash(FASTQ.Record("id", "AAGCT", collect("@BCFG")))
        @test hash(FASTQ.Record("id", "desc", "AAGCT", collect("@BCFF"))) != hash(FASTQ.Record("id", "AAGCT", collect("@BCFF")))
        @test hash(FASTQ.Record("id", "desc", "AAGCT", collect("@BCFF"))) != hash(FASTQ.Record("id", "desc", "AGTCA", collect("@BCFF")))
        @test hash(FASTQ.Record("id", "desc", "AAGCT", collect("@BCFF"))) != hash(FASTQ.Record("id", "desc2", "AAGCT", collect("@BCFF")))

        record = FASTQ.Record("""
        @SRR1238088.1.1
        AAGCTCATGACCCGTCTTACCTACACCCTTGACGAGATCGAAGGA
        +
        @BCFFFDFHHHHHJJJIJIJJIJJJJJJJJIJJJJIIIJJJIJJJ
        """)
        @test BioGenerics.isfilled(record)
        @test !FASTQ.hasdescription(record)
    end

    function test_records(rs1, rs2)
        if length(rs1) != length(rs2)
            return false
        end
        for (r1, r2) in zip(rs1, rs2)
            if FASTQ.identifier(r1) != FASTQ.identifier(r2) ||
               FASTQ.sequence(r1)   != FASTQ.sequence(r2)   ||
               FASTQ.quality(r1)    != FASTQ.quality(r2)
                return false
            end
        end
        return true
    end

    function test_fastq_parse(filename, valid)
        # Reading from a reader
        filepath = joinpath(path_of_format("FASTQ"), filename)
        reader = open(FASTQ.Reader, filepath)
        @test eltype(reader) == FASTQ.Record
        if valid
            for record in reader end
            @test true  # no error
            @test close(reader) === nothing
        else
            @test_throws Exception begin
                for record in reader end
            end
            return
        end

        # in-place parsing
        reader = open(FASTQ.Reader, filepath)
        record = eltype(reader)()
        try
            while true
                read!(reader, record)
            end
        catch ex
            close(reader)
            if !isa(ex, EOFError)
                rethrow()
            end
        end

        # Check round trip
        output = IOBuffer()
        writer = FASTQ.Writer(output)
        expected_entries = FASTQ.Record[]
        for record in open(FASTQ.Reader, filepath)
            write(writer, record)
            push!(expected_entries, record)
        end
        flush(writer)
        seekstart(output)
        read_entries = FASTQ.Record[]
        for record in FASTQ.Reader(output)
            push!(read_entries, record)
        end

        return test_records(expected_entries, read_entries)
    end
    
    valid_specimens = list_valid_specimens("FASTQ") do specimen
        spec_tags = hastags(specimen) ? sort(tags(specimen)) : String[]
        invalid_tags = sort!(["gaps", "rna", "comments", "linewrap"])
        return isempty(intersect(spec_tags, invalid_tags))    
    end
    invalid_specimens = list_invalid_specimens("FASTQ")
    for specimen in valid_specimens
        test_fastq_parse(filename(specimen), true)
    end
    for specimen in invalid_specimens
        test_fastq_parse(filename(specimen), false)
    end

    @testset "invalid quality encoding" begin
        # Sanger full range (note escape characters before '$' and '\')
        record = FASTQ.Record("""
        @FAKE0001 Original version has PHRED scores from 0 to 93 inclusive (in that order)
        ACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTAC
        +
        !"#\$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~
        """)

        # the range is not enough in these encodings
        for encoding in (:solexa, :illumina13, :illumina15)
            @test_throws ErrorException FASTQ.quality(record, encoding)
        end

        # the range is enough in these encodings
        for encoding in (:sanger, :illumina18)
            @test FASTQ.quality(record, encoding) == collect(0:93)
        end
    end

    @testset "fill ambiguous nucleotides" begin
        input = IOBuffer("""
        @seq1
        ACGTNRacgtnr
        +
        BBBB##AAAA##
        """)
        @test FASTQ.sequence(first(FASTQ.Reader(input, fill_ambiguous=nothing))) == dna"ACGTNRACGTNR"
        seekstart(input)
        @test FASTQ.sequence(first(FASTQ.Reader(input, fill_ambiguous=DNA_A)))   == dna"ACGTAAACGTAA"
        seekstart(input)
        @test FASTQ.sequence(first(FASTQ.Reader(input, fill_ambiguous=DNA_G)))   == dna"ACGTGGACGTGG"
        seekstart(input)
        @test FASTQ.sequence(first(FASTQ.Reader(input, fill_ambiguous=DNA_N)))   == dna"ACGTNNACGTNN"
        seekstart(input)
        @test FASTQ.sequence(LongSequence{DNAAlphabet{2}}, first(FASTQ.Reader(input, fill_ambiguous=DNA_A))) == dna"ACGTAAACGTAA"
    end
end

@testset "Quality scores" begin
    @testset "Decoding base quality scores" begin
        function test_decode(encoding, values, expected)
            result = Array{Int8}(undef, length(expected))
            FASTQ.decode_quality_string!(encoding, values, result, 1, length(result))
            @test result == expected
        end

        test_decode(FASTQ.SANGER_QUAL_ENCODING,
                    UInt8['!', '#', '$', '%', '&', 'I', '~'],
                    Int8[0, 2, 3, 4, 5, 40, 93])

        test_decode(FASTQ.SOLEXA_QUAL_ENCODING,
                    UInt8[';', 'B', 'C', 'D', 'E', 'h', '~'],
                    Int8[-5, 2, 3, 4, 5, 40, 62])

        test_decode(FASTQ.ILLUMINA13_QUAL_ENCODING,
                    UInt8['@', 'B', 'C', 'D', 'E', 'h', '~'],
                    Int8[0, 2, 3, 4, 5, 40, 62])

        test_decode(FASTQ.ILLUMINA15_QUAL_ENCODING,
                    UInt8['C', 'D', 'E', 'h', '~'],
                    Int8[3, 4, 5, 40, 62])

        test_decode(FASTQ.ILLUMINA18_QUAL_ENCODING,
                    UInt8['!', '#', '$', '%', '&', 'I', '~'],
                    Int8[0, 2, 3, 4, 5, 40, 93])
    end

    @testset "Encoding base quality scores" begin
        function test_encode(encoding, values, expected)
            result = Array{UInt8}(undef, length(expected))
            FASTQ.encode_quality_string!(encoding, values, result, 1, length(result))
            @test result == expected
        end

        test_encode(FASTQ.SANGER_QUAL_ENCODING,
                    Int8[0, 2, 3, 4, 5, 40, 93],
                    UInt8['!', '#', '$', '%', '&', 'I', '~'])

        test_encode(FASTQ.SOLEXA_QUAL_ENCODING,
                    Int8[-5, 2, 3, 4, 5, 40, 62],
                    UInt8[';', 'B', 'C', 'D', 'E', 'h', '~'])

        test_encode(FASTQ.ILLUMINA13_QUAL_ENCODING,
                    Int8[0, 2, 3, 4, 5, 40, 62],
                    UInt8['@', 'B', 'C', 'D', 'E', 'h', '~'])

        test_encode(FASTQ.ILLUMINA15_QUAL_ENCODING,
                    Int8[3, 4, 5, 40, 62],
                    UInt8['C', 'D', 'E', 'h', '~'])

        test_encode(FASTQ.ILLUMINA18_QUAL_ENCODING,
                    Int8[0, 2, 3, 4, 5, 40, 93],
                    UInt8['!', '#', '$', '%', '&', 'I', '~'])
    end
end

