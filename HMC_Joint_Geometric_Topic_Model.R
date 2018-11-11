#####HMC Joint Geometric Topic Model####
options(warn=0)
library(MASS)
library(lda)
library(RMeCab)
library(matrixStats)
library(Matrix)
library(data.table)
library(bayesm)
library(HMM)
library(stringr)
library(extraDistr)
library(reshape2)
library(dplyr)
library(plyr)
library(ggplot2)
#set.seed(2506787)

####�f�[�^�̔���####
##�f�[�^�̔���
k <- 20   #�g�s�b�N��
hh <- 2000   #���[�U�[��
item <- 1000   #�ꏊ��
w <- rtpois(hh, rgamma(item, 30.0, 0.225), a=1, b=Inf)   #�K�␔
f <- sum(w)   #���K�␔

##ID�ƃC���f�b�N�X�̐ݒ�
#ID�̐ݒ�
d_id <- rep(1:hh, w)
t_id <- as.numeric(unlist(tapply(1:f, d_id, rank)))
geo_id01 <- rep(1:hh, rep(item, hh))
geo_id02 <- rep(1:item, hh)

#�C���f�b�N�X�̐ݒ�
d_index <- geo_index <- list()
for(i in 1:hh){
  d_index[[i]] <- which(d_id==i)
}
for(i in 1:hh){
  geo_index[[i]] <- which(geo_id01==i)
}

##���ׂẴA�C�e�������������܂ŌJ��Ԃ�
for(rp in 1:1000){
  print(rp)
  
  ##���[�U�[�ƃA�C�e���̌o�ܓx�𐶐�
  #���[�U�[�̏ꏊ�W���𐶐�
  s <- 30 
  rate <- extraDistr::rdirichlet(1, rep(2.0, s))
  point <- as.numeric(rmnom(hh, 1, rate) %*% 1:s)
  
  #�o�ܓx�𐶐�
  longitude <- c(0, 5); latitude <- c(0, 5)
  geo_user0 <- matrix(0, nrow=hh, ncol=2)
  for(j in 1:s){
    index <- which(point==j)
    cov <- runif(2, 0.01, 0.15) * diag(2)
    cov[1, 2] <- cov[2, 1] <- runif(1, -0.6, 0.6) * prod(sqrt(diag(cov)))
    geo_user0[index, ] <- mvrnorm(length(index), c(runif(1, longitude[1], longitude[2]), runif(1, latitude[1], latitude[2])), cov)
  }
  geo_user <- min(geo_user0) + geo_user0
  plot(geo_user, xlab="�o�x", ylab="�ܓx", main="���[�U�[�̏ꏊ�W���̕��z") 
  
  
  #�X�|�b�g�̏ꏊ�W���𐶐�
  s <- 25
  rate <- extraDistr::rdirichlet(1, rep(2.0, s))
  point <- as.numeric(rmnom(item, 1, rate) %*% 1:s)
  
  #�o�ܓx�𐶐�
  longitude <- c(0, 5); latitude <- c(0, 5)
  geo_item0 <- matrix(0, nrow=item, ncol=2)
  for(j in 1:s){
    index <- which(point==j)
      if(length(index) > 0){
      cov <- runif(2, 0.005, 0.125) * diag(2)
      cov[1, 2] <- cov[2, 1] <- runif(1, -0.6, 0.6) * prod(sqrt(diag(cov)))
      geo_item0[index, ] <- mvrnorm(length(index), c(runif(1, longitude[1], longitude[2]), runif(1, latitude[1], latitude[2])), cov)
    }
  }
  geo_item <- min(geo_item0) + geo_item0
  plot(geo_item, xlab="�o�x", ylab="�ܓx", main="�X�|�b�g�̕��z") 
  
  
  #���[�U�[�Əꏊ�̃��[�N���b�h����
  d0 <- sqrt(rowSums((geo_user[geo_id01, ] - geo_item[geo_id02, ])^2))
  hist(d0, breaks=50, xlab="���[�N���b�h����", main="2�n�_�Ԃ̃��[�N���b�h�����̕��z", col="grey")
  matrix(d0, nrow=hh, ncol=item, byrow=T)
  
  ##�p�����[�^�𐶐�
  #�g�s�b�N���z�𐶐�
  alpha1 <- rep(0.1, k)
  theta <- thetat <- extraDistr::rdirichlet(hh, alpha1)
  
  #�ꏊ���z�̐���
  alpha2 <- 2.25
  beta <- betat <- 1.0   #�o���h���̃p�����[�^
  phi <- phit <- cbind(0, mvrnorm(k, rep(0, item-1), alpha2^2*diag(item-1)))
  
  
  ##�����ϐ��𐶐�
  Z_list <- V_list <- d_list <- prob_list <- list()
  VX <- matrix(0, nrow=hh, ncol=item); storage.mode(VX) <- "integer"
  
  for(i in 1:hh){
    #�g�s�b�N�𐶐�
    z <- rmnom(w[i], 1, theta[i, ])
    z_vec <- as.numeric(z %*% 1:k)
    
    #�K��m��������
    par <- exp(phi[z_vec, ]) * matrix(exp(-beta/2 * d0[geo_index[[i]]]), nrow=w[i], ncol=item, byrow=T)
    prob <- par / rowSums(par)
    
    #�K�₵���ꏊ�𐶐�
    v <- rmnom(w[i], 1, prob)
    v_vec <- as.numeric(v %*% 1:item)
    
    #�f�[�^���i�[
    d_list[[i]] <- d0[geo_index[[i]]][v_vec]
    prob_list[[i]] <- rowSums(prob * v)  
    Z_list[[i]] <- z
    V_list[[i]] <- v_vec
    VX[i, ] <- colSums(v)
  }
  #break����
  if(min(colSums(VX)) > 0) break
}

#���X�g��ϊ�
d <- unlist(d_list)
prob <- unlist(prob_list)
Z <- do.call(rbind, Z_list); storage.mode(Z) <- "integer"
v <- unlist(V_list)
sparse_data <- sparseMatrix(i=1:f, j=v, x=rep(1, f), dims=c(f, item))
sparse_data_T <- t(sparse_data)


#�f�[�^�̉���
plot(geo_user, xlab="�o�x", ylab="�ܓx", main="���[�U�[�̏ꏊ�W���̕��z") 
plot(geo_item, xlab="�o�x", ylab="�ܓx", main="�X�|�b�g�̕��z")
hist(d0, breaks=50, xlab="���[�N���b�h����", main="2�n�_�Ԃ̃��[�N���b�h�����̕��z", col="grey")


####�n�~���g�j�A�������e�J�����@��Joint Geometric Topic Model�𐄒�####
##�P�ꂲ�Ƃɖޓx�ƕ��S�����v�Z����֐�
burden_fr <- function(theta, phi, wd, w, k){
  #���S�W�����v�Z
  Bur <- theta[w, ] * t(phi)[wd, ]   #�ޓx
  Br <- Bur / rowSums(Bur)   #���S��
  r <- colSums(Br) / sum(Br)   #������
  bval <- list(Br=Br, Bur=Bur, r=r)
  return(bval)
}

##���S�f�[�^�̑ΐ��ޓx�̘a���Z�o����֐�
loglike <- function(phi, dt, d_par_matrix, d_id, hh, item, item_vec){
  #�p�����[�^��ݒ�
  phi_par <- exp(c(0, phi))
  
  #�ꏊ�I���m����ݒ�
  denom_par <- (d_par_matrix * matrix(phi_par, nrow=hh, ncol=item, byrow=T))[d_id, ]   #�����ݒ�
  prob_spot <- denom_par / as.numeric(denom_par %*% item_vec)   #�g�s�b�N���ƂɑI���m��
  
  #���S�f�[�^�̑ΐ��ޓx�̘a
  LL <- sum(log((dt * prob_spot) %*% item_vec))
  return(LL)
}

##�ꏊ�I���m���̃p�����[�^���T���v�����O���邽�߂̊֐�
#�ꏊ�I���m���p�����[�^�̑ΐ����㕪�z�̔����֐�
dloglike <- function(phi, dt, d_par_matrix, d_id, hh, item, item_vec){
  #�p�����[�^��ݒ�
  phi_par <- exp(c(0, phi))
  
  #�ꏊ�I���m����ݒ�
  denom_par <- (d_par_matrix * matrix(phi_par, nrow=hh, ncol=item, byrow=T))[d_id, ]   #�����ݒ�
  prob_spot <- denom_par / as.numeric(denom_par %*% item_vec)   #�g�s�b�N���ƂɑI���m��
  
  #���z�x�N�g�����Z�o
  sc <- -colSums(dt - prob_spot)[-1]
  return(sc)
}

#�ꏊ�I���m���p�����[�^�̃��[�v�t���b�O�@�������֐�
leapfrog <- function(r, z, D, e, L) {
  leapfrog.step <- function(r, z, e){
    r2 <- r  - e * D(z, dt, d_par_matrix, d_id0, hh, item, item_vec) / 2
    z2 <- z + e * r2
    r2 <- r2 - e * D(z2, dt, d_par_matrix, d_id0, hh, item, item_vec) / 2
    list(r=r2, z=z2) # 1��̈ړ���̉^���ʂƍ��W
  }
  leapfrog.result <- list(r=r, z=z)
  for(i in 1:L) {
    leapfrog.result <- leapfrog.step(leapfrog.result$r, leapfrog.result$z, e)
  }
  leapfrog.result
}

##�A���S���Y���̐ݒ�
R <- 1000
keep <- 2
burnin <- 200/keep
disp <- 5
LL1 <- -1000000000
iter <- 0
e <- 0.03
L <- 3

##�C���f�b�N�X�ƃf�[�^��ݒ�
#�C���f�b�N�X�̐ݒ�
v_index <- v_vec <- list()
d_vec <- sparseMatrix(sort(d_id), unlist(d_index), x=rep(1, f), dims=c(hh, f))

for(j in 1:item){
  v_index[[j]] <- which(v==j)
  v_vec[[j]] <- rep(1, length(v_index[[j]]))
}

#�f�[�^�̐ݒ�
Data <- as.matrix(sparse_data); storage.mode(Data) <- "integer"
d_par_matrix0 <- matrix(d0, nrow=hh, ncol=item, byrow=T)
item_vec <- rep(1, item)

##���O���z�̐ݒ�
alpha01 <- 0.1
alpha02 <- rep(0, item-1)
inv_tau <- solve(100 * diag(item))

##�p�����[�^�̐^�l
beta <- betat 
theta <- thetat
phi <- phit

##�����l�̐ݒ�
#�p�����[�^�̏����l
beta <- 1.0
theta <- extraDistr::rdirichlet(hh, rep(1.0, k))
phi <- cbind(0, mvrnorm(k, rep(0, item-1), 0.1 * diag(item-1)))

#�ꏊ�̑I���m���̏����l
phi_par <- t(exp(phi))
d_par <- exp(-beta/2 * d)
d_par_matrix <- matrix(exp(-beta/2 * d0), nrow=hh, ncol=item, byrow=T)
denom_par <- (d_par_matrix %*% phi_par)[d_id, ]   #�����ݒ�
prob_spot <- (phi_par[v, ] * d_par) / denom_par   #�g�s�b�N���ƂɑI���m�����Z�o

##�p�����[�^�̊i�[�p�z��
THETA <- array(0, dim=c(hh, k, R/keep))
PHI <- array(0, dim=c(k, item, R/keep))
SEG <- matrix(0, nrow=f, ncol=k)
gamma_rate <- rep(0, k)
storage.mode(SEG) <- "integer"


##�ΐ��ޓx�̊�l
#���j�O�������f���̑ΐ��ޓx
LLst <- sum(log(sparse_data %*% colSums(Data) / f))

#�x�X�g�ȑΐ��ޓx���Z�o
#�ꏊ�I���m�����X�V
phi_par <- t(exp(phit))
d_par <- exp(-beta/2 * d)
d_par_matrix <- matrix(exp(-beta/2 * d0), nrow=hh, ncol=item, byrow=T)
denom_par <- (d_par_matrix %*% phi_par)[d_id, ]   #�����ݒ�
prob_spot <- (phi_par[v, ] * d_par) / denom_par   #�g�s�b�N���ƂɑI���m�����Z�o

#�ϑ��f�[�^�̑ΐ��ޓx
LLbest <- sum(log((thetat[d_id, ] * prob_spot) %*% rep(1, k)))   


####HMC�@�Ńp�����[�^���T���v�����O####
for(rp in 1:R){   #dl��tol�ȏ�̏ꍇ�͌J��Ԃ�
  
  ##�g�s�b�N���T���v�����O
  #�g�s�b�N�̑I���m�����Z�o
  Lho <- theta[d_id, ] * prob_spot   #�ޓx�֐�
  prob_topic <- Lho / as.numeric(Lho %*% rep(1, k))   #�g�s�b�N�I���m��
  
  #�������z����g�s�b�N���T���v�����O
  Zi <- rmnom(f, 1, prob_topic)
  
  
  ##���[�U�[���ƂɃg�s�b�N���z�̃p�����[�^���T���v�����O
  wsum <- d_vec %*% Zi + alpha01   #�f�B�����N���z�̃p�����[�^
  theta <- extraDistr::rdirichlet(hh, wsum)   #�f�B���N�����z����p�����[�^���T���v�����O
  
  ##�g�s�b�N���Ƃɏꏊ���z�̃p�����[�^���T���v�����O
  for(j in 1:k){
    
    #�g�s�b�N�̊����𒊏o
    index <- which(Zi[, j]==1)
    dt <- Data[index, ]
    d_id0 <- d_id[index]
    
    #HMC�̐V�����p�����[�^�𐶐�
    rold <- rnorm(item-1)   #�W�����K���z����p�����[�^�𐶐�
    phid <- phi[j, -1]
    
    #���[�v�t���b�O�@�ɂ��1�X�e�b�v�ړ�
    res <- leapfrog(rold, phid, dloglike, e, L)
    rnew <- res$r
    phin <- res$z
    
    #�ړ��O�ƈړ���̃n�~���g�j�A��
    Hnew <- -(loglike(phin, dt, d_par_matrix, d_id0, hh, item, item_vec)) + sum(rnew^2)/2
    Hold <- -(loglike(phid, dt, d_par_matrix, d_id0, hh, item, item_vec)) + sum(rold^2)/2
    
    #HMC�@�ɂ��p�����[�^�̍̑�������
    rand <- runif(1)   #��l���z���痐���𔭐�
    gamma <- min(c(1, exp(Hold - Hnew)))   #�̑𗦂�����
    gamma_rate[j] <- gamma
    
    #alpha�̒l�Ɋ�Â��V����beta���̑����邩�ǂ���������
    flag <- gamma > rand
    phi[j, -1] <- flag*phin + (1-flag)*phid
  }

  
  #�ꏊ�I���m�����X�V
  phi_par <- t(exp(phi))
  d_par <- exp(-beta/2 * d)
  d_par_matrix <- matrix(exp(-beta/2 * d0), nrow=hh, ncol=item, byrow=T)
  denom_par <- (d_par_matrix %*% phi_par)[d_id, ]   #�����ݒ�
  prob_spot <- (phi_par[v, ] * d_par) / denom_par   #�g�s�b�N���ƂɑI���m�����Z�o
  
  
  ##�p�����[�^�̊i�[�ƃT���v�����O���ʂ̕\��
  #�p�����[�^���i�[
  if(rp%%keep==0){
    #���f���̃p�����[�^���i�[
    mkeep <- rp/keep
    THETA[, , mkeep] <- theta
    PHI[, , mkeep] <- phi
    
    #�o�[���C�����Ԃ𒴂�����g�s�b�N���i�[
    if(rp >= burnin){
      SEG <- SEG + Zi
    }
  }
  
  #�ΐ��ޓx�̌v�Z�ƃT���v�����O���ʂ��m�F
  if(rp%%disp==0){
    #�ϑ��f�[�^�̑ΐ��ޓx
    LL <- sum(log((theta[d_id, ] * prob_spot) %*% rep(1, k)))   
    
    #�T���v�����O���ʂ�\��
    print(rp)
    print(c(LL, LLbest, LLst))
    print(round(gamma_rate, 3))
  }
}

##�g�s�b�N���Ƃɏꏊ���z�̃p�����[�^�𐄒�

