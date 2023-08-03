using Distributions
using JLD
using ArgParse
using NCDatasets
using LinearAlgebra
using Random
#using DelimitedFiles
using CSV
using DataFrames
# Import EnsembleKalmanProcesses modules
using EnsembleKalmanProcesses
using EnsembleKalmanProcesses.ParameterDistributions


"""
ek_update(iteration_::Int64)

Update GW parameters ensemble using Ensemble Kalman Inversion,
return the dataframe containing all parameter values 
"""
function ek_update(iteration_::Int64, N::Int64)
    # Recover versions from last iteration
    last_iteration_parameter_file = "/scratch/users/lauraman/EKI_N${N}/iteration_$(iteration_)/paramlist.csv"
    df_params = DataFrame(CSV.File(last_iteration_parameter_file))
    colnames = names(df_params)      # should be run_ids,cwtropics,Bt_eq 
    
    # Use known u_names and n_params, could eventually set this up by reading from output file (as done in ClimateMachine example)
    u_names = ["cwtropics", "Bt_eq"] 
    n_params = length(u_names)
    u = Array(df_params[:, 2:3])

    u = Array(u')
    println(u)

    # Get observations / truth 
    println("Get ground truth")
    y_names = ["period", "amplitude"]
    yt = zeros(0)
    yt_var_list = []

    truthdir = "/home/users/lauraman/EKI_OBS/ground_truth_data/"
    truth_filename = "QBO_TT_metrics_ground_truth.csv"
    runname = "$(truthdir)/$(truth_filename)"
    df_truth = DataFrame(CSV.File(runname))
    yt_ = zeros(length(y_names))
    for (y_index, y_name) in enumerate(y_names)
        yt_[y_index] = df_truth[1, y_name] 
    end 
    println(yt_)

    # Also get variance for truth 
    y_names_var = ["cov_00", "cov_01", "cov_10", "cov_11"]
    yt_var_ = zeros(length(y_names), length(y_names))
    yt_var_[1, 1] = df_truth[1, "cov_00"]
    yt_var_[1, 2] = df_truth[1, "cov_01"]
    yt_var_[2, 1] = df_truth[1, "cov_10"]
    yt_var_[2, 2] = df_truth[1, "cov_11"]

    # Convert to diagonal covariance matrix 
    #yt_var_ = diagm(yt_var_)
    println(yt_var_)

    # Add nugget to variance (regularization)
    println(Matrix(0.1I, size(yt_var_)[1], size(yt_var_)[2]))
    yt_var_ = yt_var_ + Matrix(0.1I, size(yt_var_)[1], size(yt_var_)[2])
    println(yt_var_)
    println(yt_var_list)
    append!(yt, yt_)
    push!(yt_var_list, yt_var_)

    # Get outputs from .csv file
    println("Get outputs")
    g_names = y_names
    g_ens = zeros(N, length(g_names))
    basedir = "/scratch/users/lauraman/EKI_N${N}/iteration_$(iteration_)/"
    filename = "QBO_TT_metrics.csv"
    for run_id in 0:(N-1)
        #run_id_str = string(run_id, pad=2)
        runname = "$(basedir)/$(run_id)/$(filename)"
        df_out = DataFrame(CSV.File(runname))
        colnames = names(df_out)
        for (g_index, g_name) in enumerate(g_names)
            g_ens[run_id+1, g_index] = df_out[1, g_name]
        end

    end
    g_ens = Array(g_ens')
    println("Ensemble of periods and amplitudes:")
    println(g_ens)

    # Construct EKP
    ekobj = EnsembleKalmanProcess(u, yt_, yt_var_, Inversion())
    println(ekobj)
    # Advance EKP
    update_ensemble!(ekobj, g_ens)
    # Get new step
    u_new = get_u_final(ekobj)
    println("**NEW PARAMETERS**")
    println(u_new)

    # Return dataframe in same format as previous iteration
    u_new = Matrix(u_new')
    df_new = DataFrame(u_new, u_names)
    insertcols!(df_new, 1, :"run_ids" => df_params[:, 1])    # Keep run_ids
    return df_new
end

# Read iteration number of ensemble to be recovered
s = ArgParseSettings()
@add_arg_table s begin
    "--iteration"
    help = "Calibration iteration number"
    arg_type = Int
    default = 1
end
@add_arg_table s begin
    "--N"
    help = "Ensemble size"
    arg_type = Int
    default = 50
end
parsed_args = parse_args(ARGS, s)
iteration_ = parsed_args["iteration"]
N = parsed_args["N"]

println(iteration_)
# For reproducibility
rng_seed = 41 * iteration_
Random.seed!(rng_seed)

# Perform update
df_new = ek_update(iteration_, N)

next_iteration_ = iteration_+1
next_iteration_parameter_file = "/scratch/users/lauraman/EKI_N${N}/iteration_$(next_iteration_)/paramlist.csv"
CSV.write(next_iteration_parameter_file, string.(df_new))

println("EKI update complete, written to CSV")

