% RUN_EXPERIMENT_2 Run matrix ID experiment for sparse matrices
%
%   RUN_EXPERIMENT_2 is a script that runs an experiment where sparse
%   matrices of known rank and with known singular values are decomposed
%   using different versions of matrix interpolative decomposition (ID).
%
%   To generate the sparse matrix, the function generate_sparse_matrix_4 is
%   used. 
%
%   The following versions of matrix ID are used in the comparison:
%       1.  Matrix ID [Ch05]. More specifically, we use the implementation
%           in RSVDPACK [Vo16]. Since there no support for sparse matrices
%           in RSVDPACK, and since there is no other implementation of
%           column pivoted QR available that would allows us to implement
%           standard matrix ID on sparse matrices (to the best of our
%           knowledge), we convert the sparse tensor to full format before
%           decomposing it. This will of course limit the size of matrix
%           that can be decomposed using this method.
%       2.  Gaussian matrix ID [Ma11]. Since the implementation in [Vo16]
%           does not have support for sparse matrices, we use our own
%           implementation of Gaussian matrix ID. More specifically, we
%           implement Algorithm 6 in the appendix of [Vo16].
%       3.  SRFT matrix ID [Wo08]. Since no implementation of this
%           algorithm is available online, we use our own implementation.
%           Since there is no efficient implementation of the subsampled
%           accelerated FFT presented in the paper [Wo08] available in
%           Matlab, we use Matlab's FFT instead. Since Matlab's FFT does
%           not support sparse inputs, we need to convert the input to a
%           full matrix before applying this algorithm. As for the method
%           (1), this will also limit the size of the matrices that can be
%           decomposed using this method.
%       4.  CountSketch matrix ID (proposal). This is our proposed
%           algorithm for decomposing matrices.
%
%   All of the methods utilize column pivoted QR instead of the strongly
%   rank-revealing QR factorization of [Gu96].
%
% REFERENCES:
%   [Ch08]  H. Cheng, Z. Gimbutas, P. G. Martinsson, and V. Rokhlin. On the
%           compression of low rank matrices. SIAM J. Sci. Comput. 26(4),
%           pp. 1389-1404, 2005.
%
%   [Gu96]  M. Gu, and S. C. Eisenstat. Efficient algorithms for computing
%           a strong rank-revealing QR factorization. SIAM J. Sci. Comput.
%           17(1), pp. 848-869, 1996.
%
%   [Ma11]  P. G. Martinsson, V. Rokhlin, M. Tygert. A randomized algorithm
%           for the decomposition of matrices. Appl. Comput. Harmon. Anal.
%           30, pp. 47-68, 2011.
%
%   [Vo16]  S. Voronin, and P. G. Martinsson. RSVDPACK: An implementation
%           of randomized algorithms for computing the singular value, 
%           interpolative, and CUR decompositions of matrices on multi-core
%           and GPU architectures. arXiv:1502.05366v3 [math.NA], 2016.
%
%   [Wo08]  F. Woolfe, E. Liberty, V. Rokhlin, M. Tygert. A fast randomized
%           algorithm for the approximation of matrices. Appl. Comput.
%           Harmon. Anal. 25, pp. 335-366, 2008.

%% Settings

%Is = [10*1e+3 25*1e+3 50*1e+3 100*1e+3 250*1e+3 500*1e+3 1e+6];
%I_mem_lim = 100*1e+3;
Is = [1e+4 2*1e+4 3*1e+4 4*1e+4];
I_mem_lim = 0;

R = 10*1e+3;
K = 1e+3;
L = K + 10;
rho = 0.01;
mn = 8;
no_rand_norm_vec = 18;
no_trials = 4;
bin_file = 'data/A_mat.bin';
results_matlab_file = 'matlab_output';
verbosity = 1;

%% Main loop

% Create mat and set up matfile for saving results computed in Matlab
save_mat = matfile(results_matlab_file, 'Writable', true);
save_mat.I = zeros(1, length(Is)*no_trials);
save_mat.trial = zeros(1, length(Is)*no_trials);
save_mat.time = zeros(4, length(Is)*no_trials);
save_mat.error = zeros(4, length(Is)*no_trials);
cnt = 1;

fprintf('Starting Experiment 2...\n');

col_dens = sqrt(rho/(2*K));

for i = 1:length(Is)
    
    I = Is(i);
    
    for tr = 1:no_trials
        
        if verbosity >= 1
            fprintf('\nStarting experiments for I = %.1e, trial = %d\n', I, tr);
        end

        % Generate sparse matrix A
        if verbosity >= 1
            fprintf('Generating %d by %d sparse matrix with target density %.3f... ', I, R, rho);
        end
        A = generate_sparse_matrix_4(I, R, K, mn, col_dens);
        if verbosity >= 1
            fprintf('Done!\n')
        end

        % Save matrix A to file
        if I <= I_mem_lim
            if verbosity >= 1
                fprintf('Saving matrix to file...\n');
            end
            save_matrix_to_file(full(A), bin_file, verbosity);
            if verbosity >= 1
                fprintf('Finished writing to file!\n');
            end
        else
            fprintf('Skipping RSVDPACK Matrix ID due to size of matrix.\n')
        end

        % Compute matrix ID (RSVDPACK)
        if I <= I_mem_lim
            if verbosity >= 1
                fprintf('Running RSVDPACK matrix ID... ');
            end
            [P_SID, J_SID, time_SID] = run_matrix_id_externally(K, R);
            if verbosity >= 1
                fprintf('Done!\n');
            end
        else
            time_SID = nan;
        end

        % Compute Gaussian matrix ID
        if verbosity >= 1
            fprintf('Running Gaussian matrix ID... ');
        end
        tic_gaussian = tic;
        [P_GA, J_GA] = Gaussian_matrix_ID(A, K, L, 'qr');
        toc_gaussian = toc(tic_gaussian);
        if verbosity >= 1
            fprintf('Done!\n');
        end

        % Compute SRFT matrix ID
        if I <= I_mem_lim
            if verbosity >= 1
                fprintf('Running SRFT matrix ID... ');
            end
            tic_SRFT = tic;
            [P_SRFT, J_SRFT] = SRFT_matrix_ID(full(A), K, L);
            toc_SRFT = toc(tic_SRFT);
            if verbosity >= 1
                fprintf('Done!\n');
            end
        else
            fprintf('Skipping SRFT Matrix ID due to size of matrix.\n')
            toc_SRFT = nan;
        end

        % Compute CountSketch matrix ID
        if verbosity >= 1
            fprintf('Running CountSketched matrix ID... ');
        end
        tic_CS = tic;
        [P_CS, J_CS] = CS_matrix_ID(A, K, L, 'qr');
        toc_CS = toc(tic_CS);
        if verbosity >= 1
            fprintf('Done!\n');
        end

        % Compute errors
        if verbosity >= 1
            fprintf('Computing errors...\n');
        end
        X = randn(R, no_rand_norm_vec);
        X = X./sqrt(sum(X.^2,1));
        AX = A*X;
        if I <= I_mem_lim
            error_SID = max(sqrt(sum((AX - A(:,J_SID)*(P_SID*X)).^2, 1)));
            if verbosity >= 1
                fprintf('RSVDPACK matrix ID error: %.10e. Time: %.2f s.\n', error_SID, time_SID);
            end
        else
            error_SID = nan;
        end
        error_GA = max(sqrt(sum((AX - A(:,J_GA)*(P_GA*X)).^2, 1)));
        if verbosity >= 1
            fprintf('Gaussian matrix ID error: %.10e. Time: %.2f s.\n', error_GA, toc_gaussian);    
        end
        if I <= I_mem_lim
            error_SRFT = max(sqrt(sum((AX - A(:,J_SRFT)*(P_SRFT*X)).^2, 1)));
            if verbosity >= 1
                fprintf('SRFT matrix ID error: %.10e. Time: %.2f s.\n', error_SRFT, toc_SRFT);
            end
        else
            error_SRFT = nan;
        end
        error_CS = max(sqrt(sum((AX - A(:,J_CS)*(P_CS*X)).^2, 1)));
        if verbosity >= 1
            fprintf('CountSketch matrix ID error: %.10e. Time: %.2f s.\n', error_CS, toc_CS);
        end

        % Saving errors and times
        if verbosity >= 1
            fprintf('Done computing errors. \nSaving to file... ')
        end
        save_mat.I(1, cnt)      = I;
        save_mat.trial(1, cnt)  = tr;   
        save_mat.error(1, cnt)  = error_SID; 
        save_mat.error(2, cnt)  = error_GA; 
        save_mat.error(3, cnt)  = error_SRFT;
        save_mat.error(4, cnt)  = error_CS;
        save_mat.time(1, cnt)   = time_SID;
        save_mat.time(2, cnt)   = toc_gaussian;
        save_mat.time(3, cnt)   = toc_SRFT;
        save_mat.time(4, cnt)   = toc_CS;
        if verbosity >= 1
            fprintf('Done!\n')
        end
        cnt = cnt + 1;    
    end
end