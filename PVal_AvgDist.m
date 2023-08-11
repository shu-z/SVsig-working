 
%%%Calculates p-value with adjustments to account for
%%%fragile cluster?
%%%Added FDR Threshold so we can add this as a variable in the master file
%%%which is good programming practice!!!
%%@qqplot_flag ->  0 means no qqplot is generated, 1 means qqplot is
%%generated 
%%@ FDR_THRESHOLD gives the q value threshold below which tiles are called
%%significant
function [qFDR_tophits, pa, pval_tophits,mfull] = PVal_AvgDist(mfull, p, bins, events, sij1dx, chsize, CHR, approx_flag, qqplot_flag)
 global FDR_THRESHOLD
% general variables
mat_size = size(mfull);

intra_events=events(:,1)==events(:,4);
events_length=abs(events(intra_events,5)-events(intra_events,2));

%default is approx flag = 1?
approx_flag=1

% keep only upper diagonal part of mfull 
mfull = triu(full(mfull));
mfull(eye(mat_size)~=0) = diag(mfull)/2;
nume = sum(mfull(:));

% probability matrix
pa=p;
if issymmetric(p)
    pa=triu(p);
    pa(eye(mat_size)~=0) = diag(pa)/2;
end

%multiply background rates by 2 for simulations with larger binss
%pa = 2*pa;

    
% divide tiles with positive values from zeros 
high_k = find(mfull>=2 & pa>0);
pos_k = find(mfull==1 & pa>0);
zero_k = find(mfull==0 & pa>0);
mfull_low = full(mfull(zero_k));
mfull_pos = full(mfull(pos_k));
mfull_high = full(mfull(high_k));
p_high = pa(high_k);
p_pos = pa(pos_k);
p_zero = pa(zero_k);


% p-vals 
disp(['calculating p-val for ' num2str(length(zero_k)) ' tiles with zero events']);
rand_nnz = rand(length(zero_k),1);
tic
if ~approx_flag
    %pval_low=1-(1-p_zero).^nume.*rand(length(zero_k),1);
    %pval_low = binopdf(mfull_low, nume, p_zero).*rand_nnz+(1-binocdf(mfull_low,nume, p_zero));
    pval_low = 1-exp(-p_zero*nume);

else
    %pval_low=1-exp(-p_zero*nume).*rand(length(zero_k),1);
    disp('hi')
    pval_low=1-poisscdf(mfull_low-1,nume*p_zero);
     %pval_low = poisspdf(mfull_low, nume*p_zero).*rand_nnz+(1-poisscdf(mfull_low,nume*p_zero));

    %no random term
    %pval_low = 1-exp(-p_zero*nume);
end
toc

disp(['calculating p-val for ' num2str(length(pos_k)) ' tiles with 1 event']);
rand_nnz = rand(length(pos_k),1);
tic
if ~approx_flag
    %pval_pos = binopdf(mfull_pos, nume, p_pos).*rand_nnz+(1-binocdf(mfull_pos,nume,p_pos));
    %pval_pos without the random term
    pval_pos0 = (1-binocdf(mfull_pos,nume,p_pos));
else
    %pval_pos = poisspdf(mfull_pos, nume*p_pos).*rand_nnz+(1-poisscdf(mfull_pos-1,nume*p_pos));
    %no random term
    pval_pos = (1-poisscdf(mfull_pos-1,nume*p_pos));

end
toc

disp(['calculating support for ' num2str(length(high_k)) ' tiles with >1 events']);
tic
 t_dv=zeros(length(high_k),2);

for c1=1:length(high_k)
    [a1, a2]=ind2sub(mat_size,high_k(c1));     
    %[h, p_ks, n]=compare_avg_length( [a1 a2], bins, events, 0 );
    [p_mw, n]=compare_avg_length( [a1 a2], bins, events, 0 );

    t_dv(c1,1)=p_mw;
    t_dv(c1,2)=n;

end

p_high_s=p_high;
toc
disp(['calculating p-val for ' num2str(length(high_k)) ' tiles with >1 events']);
tic
rand_nnz = rand(length(high_k),1);

if ~approx_flag
%    pval_high = binopdf(mfull_high, nume, p_high).*rand_nnz+(1-binocdf(mfull_high,nume,p_high));
else

    %pval_high = binopdf(mfull_high, nume, p_high).*rand_nnz+(1-binocdf(mfull_high-1,nume,p_high));
    %pval_high0 is pval_high without the random term
    %Note: pval_high0 > pval_high so the random term will push a hit into
    %significance
    pval_high = (1-binocdf(mfull_high-1,nume,p_high));
end
toc

%fisher's method to combine two pvals for pval_high0 terms 

combined_pval=zeros(length(high_k),1);
for c1=1:length(pval_high)
    if t_dv(c1,2)>4
    chi_val = -2*(log(pval_high(c1)) + log(t_dv(c1,1)));
    combined_pval(c1) = 1 - chi2cdf(chi_val,4); 
else
    %combined_pval(c1) = pval_high0(c1); 
    chi_val = -2*(log(pval_high(c1)) + log(t_dv(c1,1)));
    combined_pval(c1) = 1 - chi2cdf(chi_val,4);    
    end

end
    

%pvalues for all the tiles
pval=[pval_low zero_k;pval_pos pos_k;combined_pval high_k];
%pvalues for only the tiles with high counts without the random term
combined_pval=[combined_pval high_k];

%%without fisher's method 
% pval=[pval_low zero_k;pval_pos pos_k;pval_high high_k];
% %pvalues for only the tiles with high counts without the random term
% combined_pval=[pval_high high_k];



% qq-plot  
%would want the pvals to be compared to the ones generated by
%the background model
%[] is clearly not the background model, its an empty array
%turn qqplot_flag off for now but would need to reasses to 
if qqplot_flag
   qqplot(pval(:,1),[]);
   qqplot(pval(:,1),makedist('Binomial'));
end

% calculate BH-FDR
qFDR=mafdr(pval(:,1),'BHFDR','true');
hits_idx=(qFDR<FDR_THRESHOLD);


%tophits=sum(hits_idx);

%tophits: column 1 pvalue, column 2 tile id, column 3 q-value
tophits = sortrows([pval(hits_idx,:) qFDR(hits_idx)],1);
%which top hits part of the pval_high0 tiles ( >= 2 events minus the random term)
[p_high_b,p_high_loc]=ismember(tophits(:,2),combined_pval(:,2)); 

%remove hits that are pushed out by 
max_th=max(tophits(:,1));
hits_to_remove=zeros(length(tophits),1);
for c1=1:length(tophits)
    if p_high_b(c1)==1 && combined_pval(p_high_loc(c1),1)>max_th
        hits_to_remove(c1)=1;
    end
end
tophits(logical(hits_to_remove),:)=[];

pval_tophits=tophits(:,1:2);
qFDR_tophits=tophits(:,3);

return

