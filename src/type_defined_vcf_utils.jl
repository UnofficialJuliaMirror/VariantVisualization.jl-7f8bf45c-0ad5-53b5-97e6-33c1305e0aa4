
"""
    format_reader(vcf::Matrix{Any}, element::AbstractString)
find index of chosen field to visualize
genotype is always index split(cell)[1]
"""
#function format_reader(vcf::Matrix{Any}, element::{T}) where {T<:AbstractString} #when vcf_matrix is vcf
function format_reader(vcf::Matrix{Any}, element::AbstractString) #when vcf_matrix is vcf

    format = vcf[1,9]

    s = split(format,":")
    gt_index = find(x -> x == "GT",s)
    dp_index = find(x -> x == "DP",s)
    gq_index = find(x -> x == "GQ",s) #genotype quality - look at annotated pdf to determine how to interpret
    pl_index = find(x -> x == "PL",s)
    mq_index = find(x -> x == "MQ",s)

        if element == "genotype"
            index = gt_index
        elseif element == "read_depth"
            index = dp_index
        elseif element == "-gq"
            index = gq_index
        elseif element == "-pl"
            index = pl_index
        elseif element == "-mq"
            index = mq_index
        end

        index = index[1]

    return index

end

"""
    load_vcf(x::AbstractString)
Load vcf file, clean and sort by chromosome position.
Where x is vcf file name to upload.

returns matrix and dataframe - vcf,df_vcf = load_vcf(x)

element = load_vcf(x)
df_vcf = element[2]
vcf = element[1]

"""
function load_vcf(x::AbstractString)
  readvcf = readlines(x)

  for row = 1:size(readvcf,1)

      if contains(readvcf[row], "#CHROM")
          header_col = row
          global header_col
          header_string = readvcf[row]
      end
  end

  skipstart_number=header_col-1 #this allows vcf to be loaded by readtable, the META lines at beginning of file start with "##" and interfere with readtable function - need readtable vs readdlm for reorder columns

  #df_vcf=readtable(x, skipstart=skipstart_number, separator='\t')

#can remove Base redefine methods for promote rule once fix is in place
  df_vcf = CSV.read(x, delim="\t", datarow = header_col+1, header = header_col, categorical=false, types=Dict(1=>String))
  rename!(df_vcf, Symbol("#CHROM") => :_CHROM)

 # Base.promote_rule(::Type{C}, ::Type{Any}) where {C <: CategoricalArrays.CatValue} = Any #remove this eventually

  vcf=Matrix(df_vcf)

  #load vcf as dataframe twice: once to use for matrix and other to pull header info from
  #df_vcf=readtable(x, skipstart=skipstart_number, separator='\t')

  #2) data cleaning
  ViVa.clean_column1!(vcf)

  for n = 1:size(vcf,1)

      if vcf[n, 1] != 23 && vcf[n, 1] != 24
      vcf[n, 1] = parse(Int64, vcf[n, 1])
      end

  end

  #sort rows by chr then chromosome position so are in order of chromosomal architecture
  vcf = sortrows(vcf, by=x->(x[1],x[2]))

  #1) field selection

  #a) FORMAT reader - get index of fields to visualize

    #***once genotype is selected, run format_reader on vcf to get field index
    #global index = format_reader(vcf)
    #return index

return vcf,df_vcf
#return df_vcf #QUESTION for THURSDAY - how to return two variables and define df_vcf when call load_vcf function for use in reorder_columns function

end

"""
    clean_column1!(x)
Replace String "X" and "Y" from chromosome column so all elements are Int64 type
Replaces "X" and "Y" with Int64 23 and 24, rest of chr numbers are not loaded as
Int64 and need to be same type
"""
function clean_column1!(x) #::Matrix{Any}

    for i = 1:(size(x, 1))
        x[i, 1] = x[i, 1] == "X" ? "23" : x[i, 1]
        x[i, 1] = x[i, 1] == "Y" ? "24" : x[i, 1]
        x[i, 1] = x[i, 1] == "M" ? "25" : x[i, 1]
    end


end

"""
    returnXY_column1!(x)
Replace String "23" and "24" with "X" and "Y" in chromosome column for plot labels
"""
function returnXY_column1!(x) #::Matrix{Any}

    for i = 1:(size(x, 1))
        x[i, 1] = x[i, 1] == "23" ? "X" : x[i, 1]
        x[i, 1] = x[i, 1] == "24" ? "Y" : x[i, 1]
        x[i, 1] = x[i, 1] == "25" ? "M" : x[i, 1]
    end

end

"""
    sort_genotype_array(x)
sorts genotype array for GT or DP by chromosomal location

"""

function sort_genotype_array(x)

    data=x[:,3:size(x,2)]
    chrom_positions = [parse(Int, i) for i in x[:,1:2]]
    genotype_array = hcat(chrom_positions,data)

    genotype_array = sortrows(genotype_array, by=x->(x[1],x[2]))

return genotype_array
end

"""
    clean_column1_siglist!(x)
use in load_siglist() because X and Y need to be replaced with Int
Replace String "X" and "Y" from chromosome column so all elements are Int64 type
Replaces "X" and "Y" with Int64 23 and 24, rest of chr numbers are not loaded as
Int64 and need to be same type
"""
function clean_column1_siglist!(x) #::Matrix{Any}

    #n = size(x, 1)
    for i = 1:(size(x, 1))
        x[i, 1] = x[i, 1] == "X" ? 23 : x[i, 1]
        x[i, 1] = x[i, 1] == "Y" ? 24 : x[i, 1]
    end

#=
    for i in x
        if typeof(i) == "String"
            i = parse(Int,i)
        end
    end
    =#

    #x = [parse(Int, i) for i in x]

end

"""
    genotype_cell_searcher_maf_correction(x::Matrix{Any}, index::Int64)
Genotype selection with maf correction of genotype
Note: may need to define vcf first, or get rid of conditional eval
and set 'maf_sub = maf_list_match_vcf(vcf)' inside function definition
"""

function genotype_cell_searcher_maf_correction(x::Matrix{Any}, index::Int64) #when x is output subarray of variant selection

    for row = 1:size(x,1)

        maf = match_list[row,3]

            for col = 10:size(x,2)

                cell_to_search = x[row,col]
                S = split(cell_to_search, ":")
                genotype = S[index]

                homo_variant = ["1/1" "1/2" "2/2" "1/3" "2/3" "3/3" "1/4" "2/4" "3/4" "4/4" "1/5" "2/5" "3/5" "4/5" "5/5" "1/6" "2/6" "3/6" "4/6" "5/6" "6/6" "1|1" "1|2" "2|2" "1|3" "2|3" "3|3" "1|4" "2|4" "3|4" "4|4" "1|5" "2|5" "3|5" "4|5" "5|5" "1|6" "2|6" "3|6" "4|6" "5|6" "6|6" "2/1" "3/2" "4/2" "5/2" "6/2" "4/3" "5/3" "6/3" "5/4" "6/4" "6/5" "2|1" "3|2" "4|2" "5|2" "6|2" "4|3" "5|3" "6|3" "5|4" "6|4" "6|5"]

                hetero_variant = ["0/1" "0/2" "0/3" "0/4" "0/5" "0/6" "1/0" "2/0" "3/0" "4/0" "5/0" "6/0" "0|1" "0|2" "0|3" "0|4" "0|5" "0|6" "1|0" "2|0" "3|0" "4|0" "5|0" "6|0" "1/0" "2/0" "3/0" "4/0" "5/0" "6/0" "1|0" "2|0" "3|0" "4|0" "5|0" "6|0"]

                if genotype == "./." || ".|."
                    x[row,col] = g_blue

                elseif genotype == "0/0" || "0|0"
                    x[row,col] = g_white

                else
                    for i in hetero_variant
                        if genotype == i
                            x[row,col] = g_pink
                        end
                    end

                    for i in homo_variant
                        if genotype == i
                            if maf > (0.5) && maf < (1.1)|| MAF==(0.5)
                                x[row,col] = g_white
                            elseif maf < 0.5 && MAF >= 0
                                x[row,col] = g_red
                            end
                        end
                    end

                end
            end
    end
    return x
end

"""
    genotype_cell_searcher(x::Matrix{Any}, index::Int64)
Genotype selection with no maf correction
"""
function genotype_cell_searcher(x::Array{Any,2}, index::Int64) #when x is output subarray of variant selection

        for row=1:size(x,1)

        for col = 10:size(x,2)

            cell_to_search = x[row,col]
            S = split(cell_to_search, ":")
            genotype = S[index]

            homo_variant = ["1/1" "1/2" "2/2" "1/3" "2/3" "3/3" "1/4" "2/4" "3/4" "4/4" "1/5" "2/5" "3/5" "4/5" "5/5" "1/6" "2/6" "3/6" "4/6" "5/6" "6/6" "1|1" "1|2" "2|2" "1|3" "2|3" "3|3" "1|4" "2|4" "3|4" "4|4" "1|5" "2|5" "3|5" "4|5" "5|5" "1|6" "2|6" "3|6" "4|6" "5|6" "6|6"]
            hetero_variant = ["0/1" "0/2" "0/3" "0/4" "0/5" "0/6" "1/0" "2/0" "3/0" "4/0" "5/0" "6/0" "0|1" "0|2" "0|3" "0|4" "0|5" "0|6" "1|0" "2|0" "3|0" "4|0" "5|0" "6|0"]

            if genotype == "./." #|| ".|."
                x[row,col] = g_blue

            elseif genotype == "0/0" #|| "0|0"
                x[row,col] = g_white

            else

                for i in hetero_variant
                    if genotype == i
                        x[row,col] = g_pink
                    end
                end

                for i in homo_variant
                    if genotype == i
                        x[row,col] = g_red
                    end
                end
            end
        end
    end
    return x
end

"""
    dp_cell_searcher(x::Matrix{Any}, index::Int64)
Reads depth selection maf correction.
x is output subarray of variant selection
"""
function dp_cell_searcher(x::Matrix{Any}, index::Int64)

    vcf_copy = x

    for row=1:size(vcf_copy,1)

        for col=10:size(vcf_copy,2)

            dp_cell=vcf_copy[row,col]

            S=split(dp_cell, ":")
            dp=S[index]
            vcf_copy[row,col] = dp

#= set max dp value - need to fix type issue first - categoricalarray of categorical strings cant be used in isless function  - how to set type in CSV>read function for ALL columns
                if x[row,col] > 200
                    x[row,col] = 200
                elseif x[row,col] == x[row,col]
                    x[row,col]=dp
                end
=#

        end
    end
    return vcf_copy
end

"""
    load_siglist(x::AbstractString)
    where x = filename of significant SNP location list in comma delimited format
    ex. 1,20000000
    To achieve this, can be saved in Excel as comma separated text (.csv)
"""

function load_siglist(x::AbstractString)

siglist_unsorted = readdlm(x, ',', skipstart=1)
ViVa.clean_column1_siglist!(siglist_unsorted)
siglist = sortrows(siglist_unsorted, by=x->(x[1],x[2]))

if typeof(siglist) == Array{Float64,2}
    siglist = trunc.(Int,siglist)
    return siglist
end

return siglist
end

"""
    sig_list_vcf_filter(y::Matrix{Any},x::Matrix{Any})
Siglist match filter
y is vcf
x = significant list ordered with substituted chr X/Y for 23/24
e.g. function(vcf,siglist)

"""
function sig_list_vcf_filter(y::Matrix{Any},x::Matrix{Any})

    sig_list_subarray_pre=Array{Any}(0,(size(y,2)))

        for row= 1:size(x,1)

            chr=x[row,1]
            pos=x[row,2]
            first_sub=y[(y[:,1].== chr),:]
            final_sub=first_sub[first_sub[:,2].== pos,:]
            sig_list_subarray_pre = [sig_list_subarray_pre; final_sub]
        end

        return sig_list_subarray_pre
end

    #= oringial siglist match - need to fix to make modular
#a) siglist match filter
function sig_list_vcf_filter(y,x) #where x = significant list ordered with 23s y is vcf - y is vcf

    sig_list_subarray_pre=Array{Any}(0,(size(vcf,2)))

        df1_vcf=DataFrame(vcf)
        println(df1_vcf)
        for row= 1:size(x,1)

            chr=x[row,1]
            pos=x[row,2]
            first_sub=vcf[(vcf[:,1].== chr),:]
            final_sub=first_sub[first_sub[:,2].== pos,:]
            sig_list_subarray_pre = [sig_list_subarray_pre; final_sub]
        end

        return sig_list_subarray_pre
end

=#

"""
    chromosome_range_vcf_filter(x::AbstractString,vcf::Matrix{Any})
filter vcf to include only variants within a chromosome range
"""
function chromosome_range_vcf_filter(x::AbstractString, vcf::Matrix{Any})

    a=split(x,":")
    chrwhole=a[1]
    chrnumber=split(chrwhole,"r")
    string_chr=chrnumber[2]
    chr=parse(string_chr)
    range=a[2]
    splitrange=split(range, "-")
    lower_limit=splitrange[1]
    lower_limit_int=parse(lower_limit)
    upper_limit=splitrange[2]
    upperlimit_int=parse(upper_limit)

    #make subarray within range

    first_sub=vcf[(vcf[:,1].== chr),:]
    second_sub=first_sub[(first_sub[:,2].>= lower_limit_int),:]
    chr_range_subarray=second_sub[(second_sub[:,2].<= upperlimit_int),:]
    return chr_range_subarray

end

#c) rare variants only

#=
    function rare_variant_vcf_filter(x)

        rare_variant_subarray_pre=Array{Any}(0,(size(vcf,2)))

        for row = 1:size(sub_array_maf)
            maf = sub_array_maf[row,3]
            rare_variant_subarray = vcf[(sub_array_maf[:,3].< 0.01),:]
        end
=#

#3) rearrange and select columns

#if add feature to select columns, do this before filtering rows to make filter functions perform faster? (fewer columns)

#a) rearrange columns by phenotype with use input phenotype matrix

#phenotype matrix - format must be CSV, 0's will be sorted first

function load_sort_phenotype_matrix(x::AbstractString, y::AbstractString, vcf::Array{Any,2}, df_vcf::DataFrames.DataFrame) #when x is ARGS[7] which is phenotype_matrix which is in *CSV format! and y is pheno key to sort on

    pheno = readdlm(x, ',')

    #get row numer of user-chosen phenotype characteristic to sort columns by
    row_to_sort_by = find(x -> x == y, pheno)
    row_to_sort_by = row_to_sort_by[1]

    #remove phenotype_row_labels used to identify row to sort by, so row can be sorted without strings causing issues
    pheno = pheno[:,2:size(pheno,2)]

    pheno = sortcols(pheno, by = x -> x[row_to_sort_by], rev = false)

    id_list = pheno[1,:]
    vcf_header = names(df_vcf)
    vcf_info_columns = vcf_header[1:9]

    for item = 1:size(id_list,2) #names in sample list dont match vcf so have to clean
           id_list[item] = replace(id_list[item],".","_")
           id_list[item] = Symbol(id_list[item])
    end

    new_order = vcat(vcf_info_columns,id_list)

    header_as_strings = new_order

    col_new_order=vec(new_order)

    df1_vcf = DataFrame(vcf)

    rename!(df1_vcf, f => t for (f, t) = zip(names(df1_vcf), names(df_vcf)))

    #println(typeof(names(df1_vcf))) #Array{Symbol,1} | same in test
    #println(typeof(col_new_order)) #Array{Any,1} | same in test

    vcf = df1_vcf[:, col_new_order]

    vcf = Matrix(vcf)

    return vcf
end

#b) select columns to visualize

function select_columns(x::AbstractString, vcf::Array{Any,2}, df_vcf::DataFrames.DataFrame) #where x = ARGS[#] which is name of list of samples to include

    #global vcf
    #global df_vcf

    selectedcolumns=readdlm(x)

    header_as_strings = selectedcolumns

    for item = 1:size(selectedcolumns,2) #names in sample list dont match vcf so have to clean
        selectedcolumns[item] = replace(selectedcolumns[item],".","_")
        selectedcolumns[item] = Symbol(selectedcolumns[item])
    end

    col_selectedcolumns=vec(selectedcolumns)

    df1_vcf = DataFrame(vcf)

    rename!(df1_vcf, f => t for (f, t) = zip(names(df1_vcf), names(df_vcf)))

    vcf = df1_vcf[:, col_selectedcolumns]

    vcf = Matrix(vcf)

    return vcf
end


#need to start with vcf, replace all cells with dp value as Float64 then make arrays of each col for sum
"""
avg_dp_samples(x::Array{Int64,2})
create sample_avg_list array with averages of read depth for each sample
for input into avg_sample_dp_line_chart(sample_avg_list)
where x is dp_matrix (dp's as Int64 without chromosome position columns)

"""
function avg_dp_samples(x::Array{Int64,2})

    #array_for_averages=x[:,10:size(x,2)]

    avg_dps_all = Array{Float64}(0)

    for column = 1:size(x,2)

        all_dps_patient = x[1:size(x,1),column]
        sum_dp = sum(all_dps_patient)
        avg_dp = sum_dp/(size(x,1))
        push!(avg_dps_all,avg_dp)
    end

    return avg_dps_all

end

"""
avg_dp_variant(x::Array{Int64,2})
create variant_avg_list array with averages of read depth for each sample
for input into avg_variant_dp_line_chart(variant_avg_list)
where x is dp_matrix (dp's as Int64 without chromosome position columns)

"""
function avg_dp_variant(x::Array{Int64,2})

    avg_dps_all = Array{Float64}(0)

    for row = 1:size(x,1)

        all_dps_variant = x[row,1:size(x,2)]
        sum_dp = sum(all_dps_variant)
        avg_dp = sum_dp/(size(x,2))
        push!(avg_dps_all,avg_dp)
    end

    return avg_dps_all

end


"""
list_sample_names_low_dp(variant_avg_list::Array{Float64,2},chrom_labels)
finds variant positions that have an average read depth of under 15 across all patients

"""
function list_sample_positions_low_dp(sample_avg_list::Array{Float64,1},chrom_labels)

    low_dp_index_list = Array{Int64}(0)

        for item = 1:length(sample_avg_list)
            if sample_avg_list[item] < 15
                push!(low_dp_index_list,item)
            end
        end

    low_dp_positions = Array{Tuple{Int64,Int64}}(0)

        for i in low_dp_index_list
            chrom_position = chrom_labels[i,1],chrom_labels[i,2]
            push!(low_dp_positions,chrom_position)
        end

        return low_dp_positions
end


"""
list_variant_positions_low_dp(variant_avg_list::Array{Float64,2},chrom_labels)
finds variant positions that have an average read depth of under 15 across all patients

"""
function list_variant_positions_low_dp(variant_avg_list::Array{Float64,1},chrom_labels)

    low_dp_index_list = Array{Int64}(0)

        for item = 1:length(variant_avg_list)
            if variant_avg_list[item] < 15
                push!(low_dp_index_list,item)
            end
        end

    low_dp_positions = Array{Tuple{Int64,Int64}}(0)

        for i in low_dp_index_list
            chrom_position = chrom_labels[i,1],chrom_labels[i,2]
            push!(low_dp_positions,chrom_position)
        end

        return low_dp_positions
end

"""
read_depth_threshhold(dp_array::Array{Int64,2})
sets ceiling for read depth values at dp = 100. All dp over 100 are set to 100 to visualize read depths between 0 < dp > 100 in better definition.
"""

function read_depth_threshhold(dp_array::Array{Int64,2})

dp_array[dp_array[:,:].>100].=100

return dp_array

end

"""
save_numerical_array(x::Matrix{Any},y::String)
save labelel numerical array to working directory
where x is numerical array for plotly
where y is vcf_filename
where z is vcf

"""

function save_numerical_array(x,y,z)

    df_withsamplenames = CSV.read(y, delim="\t", datarow = header_col, header = false, types=Dict(1=>String))
    samplenames=df_withsamplenames[1,10:size(df_withsamplenames,2)]

      samplenames=Matrix(samplenames)
      headings = hcat("chr","position")
      samplenames = hcat(headings,samplenames)
      chrlabels=z[:,1:2]

      chr_labeled_array_for_plotly=hcat(chrlabels, x)
      labeled_value_matrix_withsamplenames= vcat(samplenames,chr_labeled_array_for_plotly)

      writedlm("AC_gatk406_eh_PASS_withheader_value_matrix_.txt", labeled_value_matrix_withsamplenames, "\t")

end

"""
chromosome_label_generator(chromosome_labels::Array{String,2})
find chromosome label indices and create labels
find index of first instance of element in array
save indexes in vector to pass to ticvals as well as chrom labels as vector for tictext

input these into plot functions for chrom tick labels on y axis
"""

function chromosome_label_generator(chromosome_labels::Array{Any,1})
    chrom_label_indices = findfirst.(map(a -> (y -> isequal(a, y)), unique(chromosome_labels)), [chromosome_labels])
    chrom_labels = unique(chromosome_labels)
    chrom_labels = [string(i) for i in chrom_labels]

    for item=2:(length(chrom_labels))

        ratio=((chrom_label_indices[item])-(chrom_label_indices[item-1]))/(length(chromosome_labels))

        if ratio < 0.1
            font_size = "8"
            return chrom_labels,chrom_label_indices,font_size
        else
            font_size = "18"
            return chrom_labels,chrom_label_indices,font_size
        end
        #return font_size
    end

    #return chrom_labels,chrom_label_indices,font_size
end

"""
get_sample_names(reader)
produces vector of sample names with row dimension = 1

"""

function get_sample_names(reader)
    hdr=VCF.header(reader)
    sample_names=hdr.sampleID
    sample_names=reshape(sample_names,1,length(sample_names))
    sample_names=convert(Array{Symbol}, sample_names)
return sample_names
end


"""
new_sort_by_pheno_matrix()
where x is pheno_matrix
where y is trait to sort by

"""

function new_sort_by_pheno_matrix(x::AbstractString, y::AbstractString, genotype_array, sample_names) #when x is ARGS[7] which is phenotype_matrix which is in *CSV format! and y is pheno key to sort on

    pheno = readdlm(x, ',')

    #get row numer of user-chosen phenotype characteristic to sort columns by
    row_to_sort_by = find(x -> x == y, pheno)
    row_to_sort_by = row_to_sort_by[1]

    #remove phenotype_row_labels used to identify row to sort by, so row can be sorted without strings causing issues
    pheno = pheno[:,2:size(pheno,2)]

    pheno = sortcols(pheno, by = x -> x[row_to_sort_by], rev = false)

    id_list = pheno[1,:]
    vcf_header = sample_names

    for item = 1:size(id_list,2)
           #id_list[item] = replace(id_list[item],".","_") #if names in sample list dont match vcf, have to clean
           id_list[item] = Symbol(id_list[item])
    end

    new_order = vcat(vcf_info_columns,id_list)

    header_as_strings = new_order

    col_new_order=vec(new_order)

    df1_vcf = DataFrame(vcf)

    rename!(df1_vcf, f => t for (f, t) = zip(names(df1_vcf), names(df_vcf)))

    vcf = df1_vcf[:, col_new_order]

    vcf = Matrix(vcf)

    return vcf
end