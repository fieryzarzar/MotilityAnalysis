function [F,S,Stopit]=edft(X,N,I,W)

% EDFT	- Extended Discrete Fourier Transform.
%
% Function EDFT produce discrete N-point Fourier transform F and amplitude 
% spectrum S of the data vector X. Data X may contain NaN (Not-a-Number).
%
% SYNTAX
%
% [F,S,Stopit]=edft(X,N) for N>length(X) calculate F and S iteratively 
% 	(see an ALGORITHM below). If sequence X do not contain NaN and
%	N<=length(X) or N is not specified, EDFT return the same results
%	as fast Fourier transform: F=fft(X,N) or F=fft(X) and S=F/N. 
%
% [F,S,Stopit]=edft(X,N,I) performs edft(X,N) with limit I for maximum number of 
%	iterations. Default value for I is set by parameter Miteration=30, that is,
%	edft(X,N)=edft(X,N,30). To complete iteration process faster, the value
%	for 'Miteration' should be decreased.
%
% [F,S,Stopit]=edft(X,N,I,W) execute edft(X,N,I) with initial conditions defined
%	by weight vector W. Default values for W are ones(size(F)). W should
%	have at least length(X) nonzero elements to pass Stopit=1 criteria.
%
%    Stopit is informative (optional) output parameter. The first row of Stopit 
%	    showing the number of performed iteration, the second row indicate 
%	    breaking of iteration reason and may have the following values: 
%	0 - Maximum number of iteration performed. If length(X)<=N, only one 
%	    EDFT iteration is performed (I=1).  
%	1 - The correlation matrix R=E*diag(W/N)*E' is ill conditioned. If this 
%	    occur in the first EDFT iteration, then outputs F and S are zeros. 
%	2 - Sum of outputs division sum(F./S) is not equal to K*N within Relative
%           deviation 'Rdeviat=0.0005'. In that case calculations were interrupted
%           because of results could be inaccurate.
%	3 - Relative threshold 'Rthresh=0.0001' reached. To complete iteration
%	    process faster, the value for 'Rthresh' should be increased.
%
% ALGORITHM
%
%    Input: 
%	X - input sequence.
%	N - length of discrete Fourier transform.
%	I - (optional) number of maximum iteration. If not specified, I=30. 
%	W - (optional) weight vector W. If not specified, weight
%		W = ones(1,N); used as input for the first iteration.
%	E - Fourier transform basis matrix:
%		E=exp(-i*2*pi*(0:length(X)-1)'*(0:N-1)/N);
%	If part of unknown samples in sequence X are replaced by NaN then time
%	vector (0:length(X)-1) is changed to exclude time moments where NaN inserted.
%
%    Output F and S for each EDFT iteration are calculated by following formulas:
%	1. R=E*diag(W/N)*E';
%	EDFT using function ifft to calculate R faster.  
%	2. F=W.*(X*inv(R)*E);
%	   S=(X*inv(R)*E)./diag(E'*inv(R)*E).';
%	Levinson-Durbin recursion used for inverse of toeplitiz R. 
%	Function fft applied to speed up matrix multiplications.
%	3. W=S.*conj(S); W used as input to the next EDFT iteration.
%    A special case: if length(X) is equal to N, the EDFT output do not depend on
%	selected weight vector W and is calculated in non-iterative way.   
%
% FEATURES of EDFT:
%
%	1. EDFT output F is the N-point Fourier transform of sequence X.
%	The Power Spectral Density (PSD) function can be calculated by
%	the following formula: abs(F).^2/(N*T), T - sampling period.
%	2. EDFT can extrapolate input sequence X to length N.
%	That is, if apply EDFT for N>length(X), get the results:
%	F=edft(X,N)=edft(Y)=fft(Y); Y=ifft(F), where Y is input sequence X
%	plus non-zero forward and backward extrapolation of X to length N.
%	3. EDFT output S estimate amplitudes and phases of sinusoidal
%	components in input sequence X. 
%	4. EDFT can increase frequency resolution N/length(X) times.
%	Division of outputs 1/(T*F./S) demonstrate the frequency resolution of EDFT.
%	The following is true for any EDFT iteration: 
%		0<F./S<=N,
%		sum(F./S)=N*length(X)
%	5. EDFT input sequence X may contain NaN.
%	NaN indicate unavailable data or missing samples or data segments in
%	sequence X. EDFT Outputs F and S are calculated by applying slower
%	algorithm then in case of X without NaN.
%	
% If X is a matrix, the EDFT operation is applied to each column.
%
% See also FFT, IFFT, FFTSHIFT.
%
% Email: 	vilnislp@gmail.com
%
% Reference: 	V. Liepin'sh, "An algorithm for evaluation a discrete Fourier transform for 
% incomplete data", Automatic control and computer sciences, Vol.30, No.3, pp.27-40, 1996.
%
% NOTE: The first version of file (gdft.m) was submitted on 10/7/1997 as Matlab 4.1 code. 

% Default parameters for EDFT
Miteration=30;		% limit for maximum number of iteration (Stopit 0). 
Rdeviat=0.0005;		% Value for relative deviation (Stopit 2).
Rthresh=0.0001;		% Value for relative threshold (Stopit 3).

% Checking input argument X.
if nargin==0,
    error('Not enough input arguments. See help edft.')
end
if sum(any(isinf(X))),
    error('Input argument X contain Inf.  See help edft.')
end
if size(X,1)==1,
    X=X.';
    trf=1;		% X is row vector
else
    trf=0;		% X is 2 dim array
end
[K L]=size(X);		% K - length of input sequence X

% Checking input argument N.
if nargin>1,
    if isempty(N),N=K;end
    N=floor(N(1));
    if ~isfinite(N)|N<1|isempty(N),
        error('Input argument N<1 or contain Inf or NaN. See help edft.')
    end
    if N<K,
        X=X(1:N,:);	% truncate X if has more than N points
	K=N;
    end
else
    N=K;
end

% Checking X for NaN.
Xnan=~isnan(X);		% Xnan - indicate samples as '1' , NaN as '0'
if N==1,
    KK=Xnan;
else
    KK=sum(Xnan);	% KK - length of input sequence X without NaN
end

% Checking input argument I.
if nargin<3,
     I=Miteration;	% Set default value for I.
else
    if isempty(I),I=Miteration;end
    I=floor(I(1));
    if ~isfinite(I)|I<1,
        error('Input argument I < 1 or contain Inf or NaN. See help edft.')
    end   
end

% Checking of input argument W.
if nargin<4,
    W=ones(N,L);	% Set default values for W
else
    if sum(~all(isfinite(W))),
        error('Input argument W contain Inf or NaN. See help edft.')
    end
    if trf==1,W=W.';end
    if (size(W,1)~=N)|(size(W,2)~=L),
        error('Incorrect size of input argument W. See help edft.')
    end
    W=W.*conj(W);  
end

% Fill with zeros in output matrixes F and S.
F=zeros(N,L);
S=zeros(N,L);

%=====================================================================
% Perform EDFT iterations for each X column l
%=====================================================================
for l=1:L,	    

  if KK(l)==N|K==1, 
    if K==1&N~=1, 		% Special case:
       F(:,l)=fft(X(:,l),N).';	% if length(X)=N or 1, output of  
    else			% the EDFT is equal to the FFT. 
       F(:,l)=fft(X(:,l),N);
    end	
    S(:,l)=F(:,l)/N;		
    Stopit(:,l)=[1; 0];
  else
    Stopit(:,l)=[I; 0];		% Set default value for Stopit.
  
    if KK(l)==K,
%=====================================================================
% KK(l)=K, X(:,l) do not contain NaN -> Applying faster algorithm.
%=====================================================================
    for it=1:I,					

% Calculate correlation vector R.
	R=ifft(W(:,l));

% Stopit 1: Break iterations if correlation matrix ill conditioned.
	if rcond(toeplitz(R(1:K)))<eps
	    Stopit(:,l)=[it-1; 1];
	    break
        end						

% Perform inverse of R : Levinson-Durbin recursion.
	r=-R(2)/R(1);			
	V=R(1)-R(2)*conj(R(2))/R(1);
	for n=1:K-2,				
	    alfa=[1 r.']*R(n+2:-1:2);		
	    rho=-alfa/V;
	    V=V+rho*conj(alfa);
	    r=[r+rho*conj(flipud(r));rho];
	end
	r=[1;r];
	rc=r;

% Calculate vectors ERE=diag(E'*inv(R)*E) and XR=X*inv(R).
	XR=zeros(K,1);
	RE=zeros(K,1);
	for k=1:K/2,
	    k0=K-k+1;
	    k1=2:K-2*k+1;
	    k2=k+1:K-k;
	    k3=k:K-k+1;
	    RE(1)=RE(1)+2*rc(k);
	    RE(k0-k+1)=RE(k0-k+1)+2*rc(k0);
	    RE(k1)=RE(k1)+4*rc(k2);
	    XR(k)=XR(k)+rc(k3)'*X(k3,l);
	    XR(k0)=XR(k0)+(flipud(rc(k3))).'*X(k3,l);
	    XR(k2)=XR(k2)+rc(k2)*X(k,l)+flipud(conj(rc(k2)))*X(k0,l);
	    rc(k2)=rc(k2-1)+conj(r(k+1))*r(k2)-r(k0)*flipud(conj(r(k2+1)));    
	end
	if round(K/2)>K/2,
	    RE(1)=RE(1)+rc(k+1);
	    XR(k+1)=XR(k+1)+X(k+1,l)*rc(k+1);
	end
	ERE=real(fft(RE,N));
	W(:,l)=W(:,l)/real(V);

% Stopit 2: Break iterations if sum(F./S) is not equal to N*K.
	if abs(ERE.'*W(:,l)/N/K-1)>Rdeviat
           Stopit(:,l)=[it-1; 2];
	   break
	end

% Calculate outputs for iteration it:
%	Amplitude Spectrum (S);
%	N-point Fourier Transform (F).
	F(:,l)=fft(XR,N);
	S(:,l)=F(:,l)./ERE;
	F(:,l)=F(:,l).*W(:,l);

% Calculate weight vector for next iteration.
	W(:,l)=S(:,l).*conj(S(:,l));

% Stopit 3: Break iterations if relative threshold reached.
	SW(it)=sum(W(:,l));
	if it>1,
	    thit=abs(SW(it-1)-SW(it))/SW(1);
	    if thit<=Rthresh,
		Stopit(:,l)=[it; 3];
		break
	    end
	end	
    end     
%=============End of faster algorithm ==================================

    else	
%=====================================================================
% KK(l)<K, X(:,l) contain NaN -> Applying slower algorithm.
%=====================================================================
    if KK(l)==0
	F(:,l)=F(:,l)*NaN;S(:,l)=S(:,l)*NaN;	% Output NaN if data column has all NaN
        else    
	X(find(~Xnan(:,l)),l)=zeros(K-KK(l),1);	% Replace NaN by 0 in X
	t=find(Xnan(:,l));			% Sample numbers
	INVR=zeros(K);	
	ER=zeros(K,1);

	for it=1:I,

% Calculate correlation matrix R by applying ifft.
	RT=ifft(W(:,l));
	R=toeplitz(RT(1:K));

% Stopit 1: Break iterations if correlation matrix ill conditioned.	
	if rcond(R(t,t))<eps
	    Stopit(:,l)=[it-1; 1];  
	    break
	end

% Inverse of R and calculate ERE=diag(E'*inv(R)*E) by applying fft.
	INVR(t,t)=inv(R(t,t));
	ER(1)=trace(INVR);
	for k=1:K-1
	    ER(k+1,1)=sum(diag(INVR,k)+conj(diag(INVR,-k)));
	end
	ERE=real(fft(ER,N));
   
% Stopit 2: Break iterations if sum(F./S) is not equal to N*KK.
	if abs(ERE.'*W(:,l)/N/KK(l)-1)>Rdeviat,
	    Stopit(:,l)=[it-1; 2];
	    break
	end

% Calculate outputs for iteration it:
%	Amplitude Spectrum (S)
%	N-point Fourier Transform (F)
	F(:,l)=fft(conj(INVR)*X(:,l),N);
	S(:,l)=F(:,l)./ERE;
	F(:,l)=F(:,l).*W(:,l);

% Calculate weight vector for the next iteration.
	W(:,l)=S(:,l).*conj(S(:,l));

% Stopit 3: Break iterations if relative threshold reached.
	SW(it)=sum(W(:,l));
	if it>1,
	    thit=abs(SW(it-1)-SW(it))/SW(1);
	    if thit<=Rthresh,
		Stopit(:,l)=[it; 3];
		break
	    end
	end	
        end		
    end         
%=============End of slower algorithm============================
    end
  end
end

% Adjust size of EDFT output.
if trf==1,F=F.';S=S.';end
