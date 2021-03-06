function nrm = s_norm(X, tol, varargin)
% S_NORM Compute the s-norm of the ktensor X
%
%   This function requires Tensor Toolbox version 2.6 [Ba15].
%
%   nrm = S_NORM(X, tol) computes the s-norm of the tensor X. The iteration
%   terminates when the change in the norm estimate (lambda) is less than
%   tol. 
%
%   nrm = S_NORM(___, 'verbosity', verbosity) is used to control the
%   verbosity of the execution of the script. There are three levels: 0 is
%   minimal verbosity, 1 is intermediate verbosity, and 2 is maximum
%   verbosity.
%
%   nrm = S_NORM(___, 'init', init) is used to control the type of
%   initialization used. There are currently two options: '1' just takes
%   the first column vector of each factor matrix, and 'mean' uses the
%   average over all columns of the factor matrices as initialization.
%
%   The code is based on the algorithm described in [Bi15].
%   
% REFERENCES:
%
%   [Ba15]  B. W. Bader, T. G. Kolda and others. MATLAB Tensor Toolbox 
%           Version 2.6, Available online, February 2015. 
%           URL: http://www.sandia.gov/~tgkolda/TensorToolbox/.
%
%   [Bi15]  D. J. Biagioni, D. Beylkin, G. Beylkin. Randomized 
%           interpolative decomposition of separated representations. J. 
%           Comput. Phys. 281, pp. 116-134, 2015.

% Author:   Osman Asif Malik
% Email:    osman.malik@colorado.edu
% Date:     January 29, 2019

%% Handle optional inputs

params = inputParser;
addParameter(params, 'verbosity', 0);
addParameter(params, 'init', '1')
addParameter(params, 'maxit', 1000)
parse(params, varargin{:});

verbosity = params.Results.verbosity;
init = params.Results.init;
maxit = params.Results.maxit;

%% Get relevant tensor properties

N = ndims(X);
R = ncomponents(X);

%% Initialize rank-1 approximation

A = cell(N, 1);
if strcmp(init, '1')
    for n = 2:N
        A{n} = X.U{n}(:,1);
    end
elseif strcmp(init, 'mean')
    for n = 2:N
        A{n} = mean(X.U{n}, 2);
    end
end
lambda = X.lambda(1);

%% Compute inner products

ip = zeros(R, N);
for n = 2:N
    ip(:, n) = X.U{n}.'*A{n};
end

%% Main loop: Run until convergence 

Ns = 1:N;
for it = 1:maxit
    lambda_old = lambda;
    for n = 1:N-1
        A{n} = X.U{n} * (X.lambda.*prod(ip(:, Ns~=n), 2));
        lambda = norm(A{n});
        A{n} = A{n} / lambda;
        ip(:, n) = X.U{n}.'*A{n};
    end
    if verbosity > 1
        fprintf('Finished iteration %d. Current lambda is %.6e.\n', it, lambda);
    end
    if abs(lambda_old - lambda) < tol
        break
    end
end
nrm = lambda;

if verbosity > 0
    fprintf('Finished computing s-norm: %.6e. Iterations required: %d\n', nrm, it);
end

end