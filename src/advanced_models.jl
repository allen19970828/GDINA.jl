# ============================================================================
# advanced_models.jl — Advanced CDM Extensions (Sequential, DTM, etc.)
# ============================================================================

export expand_sequential_data, expand_nominal_data

"""
    expand_sequential_data(data::AbstractMatrix, categories::Vector{Int}) -> Matrix{Union{Int8, Missing}}

Transforms ordinal/polytomous response data into pseudo-dichotomous data for 
Sequential G-DINA estimation (Ma & de la Torre, 2016).

# Arguments
- `data`: N × J matrix of polytomous responses (scores 0, 1, ..., H_j)
- `categories`: Vector of length J, specifying the maximum score (H_j) for each item.

# Returns
- A pseudo-dichotomous matrix of size N × (∑ H_j).
- Pseudo-items represent the sequential steps to achieve the score.
  - If score is x: steps 1 to x are 1, step x+1 is 0, steps > x+1 are missing.
  - If score is maximum (H_j): steps 1 to H_j are all 1.

# Example
An item with max score 3 (H=3).
- Score 0 -> [0, missing, missing]
- Score 1 -> [1, 0, missing]
- Score 2 -> [1, 1, 0]
- Score 3 -> [1, 1, 1]

You can then run `gdina(expanded_data, Q_seq)` where `Q_seq` has (∑ H_j) rows 
representing the attribute requirements for each step.
"""
function expand_sequential_data(data::AbstractMatrix, categories::Vector{Int})
    N, J = size(data)
    if length(categories) != J
        throw(ArgumentError("Length of categories vector must match number of columns in data."))
    end
    
    total_steps = sum(categories)
    expanded = Matrix{Union{Int8, Missing}}(undef, N, total_steps)
    
    for i in 1:N
        col_idx = 1
        for j in 1:J
            H = categories[j]
            score = data[i, j]
            
            if ismissing(score) || isnan(score) || score < 0
                for step in 1:H
                    expanded[i, col_idx + step - 1] = missing
                end
            else
                s = round(Int, score)
                s = clamp(s, 0, H)
                
                for step in 1:H
                    if step <= s
                        expanded[i, col_idx + step - 1] = 1
                    elseif step == s + 1
                        expanded[i, col_idx + step - 1] = 0
                    else
                        expanded[i, col_idx + step - 1] = missing
                    end
                end
            end
            col_idx += H
        end
    end
    
    return expanded
end

"""
    expand_nominal_data(data::AbstractMatrix, categories::Vector{Int}) -> Matrix{Union{Int8, Missing}}

Transforms nominal/multiple-choice response data into binary dummy indicators.
Used for approximating Multiple-Choice DINA (MC-DINA) by analyzing each option 
as a separate binary pseudo-item.

# Arguments
- `data`: N × J matrix of nominal responses (choices 1, 2, ..., C_j)
- `categories`: Vector of length J, specifying the number of choices (C_j) for each item.

# Returns
- A matrix of size N × (∑ C_j) containing binary indicators.
- If an examinee chooses option c, the c-th pseudo-item is 1, and the others for that item are 0.
- Note: True MC-DINA uses a multinomial likelihood constraint (∑ P = 1). 
  This function allows using the standard binary G-DINA engine to independently model 
  the probability of choosing each distractor.
"""
function expand_nominal_data(data::AbstractMatrix, categories::Vector{Int})
    N, J = size(data)
    if length(categories) != J
        throw(ArgumentError("Length of categories vector must match number of columns in data."))
    end
    
    total_options = sum(categories)
    expanded = Matrix{Union{Int8, Missing}}(undef, N, total_options)
    
    for i in 1:N
        col_idx = 1
        for j in 1:J
            C = categories[j]
            choice = data[i, j]
            
            if ismissing(choice) || isnan(choice) || choice < 1 || choice > C
                for opt in 1:C
                    expanded[i, col_idx + opt - 1] = missing
                end
            else
                c = round(Int, choice)
                for opt in 1:C
                    expanded[i, col_idx + opt - 1] = (opt == c) ? 1 : 0
                end
            end
            col_idx += C
        end
    end
    
    return expanded
end
