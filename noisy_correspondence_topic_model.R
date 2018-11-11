#####�m�C�Y����Ή��g�s�b�N���f��#####
options(warn=0)
library(MASS)
library(lda)
library(RMeCab)
library(matrixStats)
library(Matrix)
library(data.table)
library(bayesm)
library(HMM)
library(extraDistr)
library(reshape2)
library(dplyr)
library(plyr)
library(ggplot2)

#set.seed(2506787)

####�f�[�^�̐���####
#set.seed(423943)
#�����f�[�^�̐ݒ�
k <- 15   #�g�s�b�N��
vec_k <- rep(1, k)
d <- 5000   #������
v <- 1200   #��b��
w <- rpois(d, rgamma(d, 40, 0.2))   #1����������̒P�ꐔ
f <- sum(w)   #���P�ꐔ
a1 <- 200   #�g�s�b�N�Ɋ֌W�̂���^�O��
a2 <- 100   #�g�s�b�N�Ɋ֌W�̂Ȃ��^�O��
a <- a1 + a2   #�⏕�ϐ���
x <- rtpois(d, 50, 2, Inf)
f1 <- sum(w)
f2 <- sum(x)

#ID�̐ݒ�
w_id <- rep(1:d, w)
a_id <- rep(1:d, x)

#�p�����[�^�̐ݒ�
#�g�s�b�N���z��ݒ�
alpha0 <- rep(0.15, k)   #�����̃f�B���N�����O���z�̃p�����[�^
beta0 <- rbeta(sum(x), 0.55, 0.175)

#�P�ꕪ�z��ݒ�
index <- apply(rmnom(v, f, rep(1, k)), 1, which.max)
alpha1 <- rep(0.04, v)
alpha2 <- c(rep(0.1, a1), rep(0.0001, a2))   #�g�s�b�N�Ɋ֌W�̂���^�O�̃f�B�N�������O���z�̃p�����[�^
alpha3 <- c(rep(0.0001, a1), rep(1.0, a2))   #�g�s�b�N�Ɋ֌W�̂Ȃ��^�O�̃f�B�N�������O���z�̃p�����[�^


##���f���Ɋ�Â��P��𐶐�
rp <- 0
repeat {
  rp <- rp + 1
  print(rp)
  
  #�f�B���N�����z����p�����[�^�𐶐�
  thetat <- theta <- extraDistr::rdirichlet(d, alpha0)   #�����̃g�s�b�N���z���f�B���N���������琶��
  phit <- phi <- extraDistr::rdirichlet(k, alpha1)   #�P��̃g�s�b�N���z���f�B���N���������琶��
  lambda <- matrix(0, nrow=d, ncol=k)   #�����Ɋ܂ރg�s�b�N������⏕���̃g�s�b�N�ɂ��邽�߂̊m�����i�[����s��
  omegat <- omega <- extraDistr::rdirichlet(k, alpha2)   #�⏕���̃g�s�b�N���z���f�B�N�����������琶��
  gammat <- gamma <- extraDistr::rdirichlet(1, alpha3)   #�g�s�b�N�Ɋ֌W�̂Ȃ��^�O
  omega0 <- rbind(omega, gamma)   #�P�ꕪ�z�̌���
  
  #�P��o���m�����Ⴂ�g�s�b�N�����ւ���
  index <- which(colMaxs(phi) < (k*10)/f)
  for(j in 1:length(index)){
    phi[as.numeric(rmnom(1, 1, extraDistr::rdirichlet(1, alpha0)) %*% 1:k), index[j]] <- (k*10)/f
  }
  phit <- phi
  
  ##�������z����g�s�b�N����ђP��f�[�^�𐶐�
  WX <- matrix(0, nrow=d, ncol=v)
  AX <- matrix(0, nrow=d, ncol=a)
  word_list <- list()
  aux_list <- list()
  Z0 <- rep(0, sum(x)) 
  Z1_list <- list()
  Z2_list <- list()
  
  #�������ƂɃg�s�b�N�ƒP��𒀎�����
  for(i in 1:d){

    #�����̃g�s�b�N���z�𐶐�
    z1 <- rmnom(w[i], 1, theta[i, ])   #�����̃g�s�b�N���z�𐶐�
    z1_vec <- as.numeric(z1 %*% 1:k)
    
    #�����̃g�s�b�N���z����P��𐶐�
    word <- rmnom(w[i], 1, phi[z1_vec, ])   #�����̃g�s�b�N����P��𐶐�
    word_vec <- colSums(word)   #�P�ꂲ�Ƃɍ��v����1�s�ɂ܂Ƃ߂�
    WX[i, ] <- word_vec
    
    #�����̃g�s�b�N���z����⏕�ϐ��𐶐�
    #�����Ő����������g�s�b�N�݂̂�⏕���̃g�s�b�N���z�Ƃ���
    lambda[i, ] <- colSums(z1) / w[i]   #�⏕���̃g�s�b�N���z
    
    #�x���k�[�C���z����g�s�b�N�Ɋ֌W�����邩�ǂ����𐶐�
    index <- which(a_id==i)
    Z0[index] <- rbinom(length(index), 1, beta0[index])
  
    #�⏕���̃g�s�b�N�𐶐�
    z2_aux <- rmnom(x[i], 1, lambda[i, ])
    z2 <- cbind(z2_aux * Z0[index], 1-Z0[index])
    z2_vec <- as.numeric(z2 %*% 1:(k+1))
    
    #�����������g�s�b�N�̒P�ꕪ�z�ɏ]���P��𐶐�
    aux <- rmnom(x[i], 1, omega0[z2_vec, ])
    aux_vec <- colSums(aux)
    AX[i, ] <- aux_vec
    
    #�����g�s�b�N����ѕ⏕���g�s�b�N���i�[
    Z1_list[[i]] <- z1
    Z2_list[[i]] <- z2
    word_list[[i]] <- as.numeric(word %*% 1:v)
    aux_list[[i]] <- as.numeric(aux %*% 1:a)
  }
  if(min(colSums(AX)) > 0 & min(colSums(WX)) > 0){
    break
  }
}

#�f�[�^�s��𐮐��^�s��ɕύX
Z1 <- do.call(rbind, Z1_list)
Z2 <- do.call(rbind, Z2_list)
wd <- unlist(word_list)
ad <- unlist(aux_list)
storage.mode(WX) <- "integer"
storage.mode(AX) <- "integer"
r0 <- c(mean(Z0), 1-mean(Z0))

#�P��x�N�g�����s��
word_data <- sparseMatrix(1:f1, wd, x=rep(1, f1), dims=c(f1, v))
aux_data <- sparseMatrix(1:f2, ad, x=rep(1, f2), dims=c(f2, a))


####�}���R�t�A�������e�J�����@�őΉ��g�s�b�N���f���𐄒�####
##�P�ꂲ�Ƃɖޓx�ƕ��S�����v�Z����֐�
burden_fr <- function(theta, phi, wd, w, k, vec_k){
  #���S�W�����v�Z
  Bur <- theta[w, ] * t(phi)[wd, ]   #�ޓx
  Br <- Bur / as.numeric(Bur %*% vec_k)   #���S��
  bval <- list(Br=Br, Bur=Bur)
  return(bval)
}


##�A���S���Y���̐ݒ�
R <- 3000   #�T���v�����O��
keep <- 2   #2���1��̊����ŃT���v�����O���ʂ��i�[
disp <- 10
iter <- 0
burnin <- 1000/keep

##�C���f�b�N�X��ݒ�
d_dt <- sparseMatrix(w_id, 1:f1, x=rep(1, f1), dims=c(d, f1))
a_dt <- sparseMatrix(a_id, 1:f2, x=rep(1, f2), dims=c(d, f2))
word_dt <- t(word_data)
aux_dt <- t(aux_data)

##���O���z�̐ݒ�
#�n�C�p�[�p�����[�^�̎��O���z
alpha01 <- 0.25
alpha02 <- 0.25
beta01 <- 0.01
beta02 <- 0.01
s0 <- 0.01
v0 <- 0.01

##�p�����[�^�̐^�l
theta <- thetat
phi <- phit
omega <- omegat
gamma <- gammat
r <- 0.5

##�p�����[�^�̏����l
theta <- extraDistr::rdirichlet(d, rep(1, k))   #�����g�s�b�N�̃p�����[�^�̏����l
phi <- extraDistr::rdirichlet(k, rep(2.0, v))   #�P��g�s�b�N�̃p�����[�^�̏����l
omega <- extraDistr::rdirichlet(k, rep(10, a))   #�^�O�̃g�s�b�N�̃p�����[�^�̏����l
gamma <- as.numeric(extraDistr::rdirichlet(1, rep(10, a)))   #���e�Ɗ֌W�̃^�O�̃p�����[�^�̏����l
r <- 0.5   #���e�Ɋ֌W�����邩�ǂ����̍�����

##�p�����[�^�̊i�[�p�z��
THETA <- array(0, dim=c(d, k, R/keep))
PHI <- array(0, dim=c(k, v, R/keep))
OMEGA <- array(0, dim=c(k, a, R/keep))
GAMMA <- matrix(0, nrow=R/keep, ncol=a)
LAMBDA <- rep(0, R/keep)
Z_SEG <- rep(0, f2)
W_SEG <- matrix(0, nrow=f1, ncol=k)
A_SEG <- matrix(0, nrow=f2, ncol=k+1)
storage.mode(W_SEG) <- "integer"
storage.mode(A_SEG) <- "integer"
storage.mode(Z_SEG) <- "integer"
gc(); gc()

##�ΐ��ޓx�̊�l
LLst1 <- sum(log((colSums(WX) / f1)[wd]))
LLst2 <- sum(log((colSums(AX) / f2)[ad]))
LLst <- LLst1 + LLst2


####�M�u�X�T���v�����O�Ńp�����[�^���T���v�����O####
for(rp in 1:R){
  
  ##�P��g�s�b�N���T���v�����O
  #�P�ꂲ�ƂɃg�s�b�N�̏o���m�����v�Z
  word_par <- burden_fr(theta, phi, wd, w_id, k, vec_k)
  word_rate <- word_par$Br
  
  #�������z����P��g�s�b�N���T���v�����O
  Zi1 <- rmnom(f1, 1, word_rate)   
  z1_vec <- as.numeric(Zi1 %*% 1:k)
  
  
  ##�P��g�s�b�N�̃p�����[�^���X�V
  #�f�B�N�������z����theta���T���v�����O
  wsum0 <- as.matrix(d_dt %*% Zi1)
  wsum <- wsum0 + alpha01   #�f�B�N�������z�̃p�����[�^
  theta <- extraDistr::rdirichlet(d, wsum)   #�p�����[�^���T���v�����O
  
  #�f�B�N�������z����phi���T���v�����O
  vf <- as.matrix(t(word_dt %*% Zi1)) + beta01   #�f�B�N�������z�̃p�����[�^
  phi <- extraDistr::rdirichlet(k, vf)   #�p�����[�^���T���v�����O
  
  
  ##�^�O�������̃g�s�b�N�Ɗ֘A�����邩�ǂ���������
  #�����������P��g�s�b�N����⏕���̃g�s�b�N���z��ݒ�
  theta_aux <- wsum0 / w
  
  #�x���k�[�C���z�̊m�����v�Z
  aux_par <- theta_aux[a_id, ] * t(omega)[ad, ]   #�⏕���g�s�b�N�̖ޓx
  aux_sums <- as.numeric(aux_par %*% vec_k)
  tau01 <- r * aux_sums   #�⏕���g�s�b�N�̊����ޓx
  tau02 <- (1-r) * gamma[ad]   #�m�C�Y�⏕�ϐ��̊����ޓx
  tau <- tau01 / (tau01 + tau02)  
  
  #�x���k�[�C���z���m�C�Y�̐��ݕϐ��𐶐�
  z <- rbinom(f2, 1, tau)
  
  #�x�[�^���z���獬�������T���v�����O
  n <- sum(z)
  s1 <- n + s0
  v1 <- f2 - n + v0
  r <- rbeta(1, s1, v1)   #���������T���v�����O
  
  ##�⏕���g�s�b�N���T���v�����O
  #z=1�̏ꍇ�A�^�O���ƂɃg�s�b�N�̏o�������v�Z
  index_z <- which(z==1)   #z=1�̂ݒ��o
  aux_rate <- aux_par[index_z, ] / aux_sums[index_z]
  
  #�������z����⏕���g�s�b�N���T���v�����O
  Zi2 <- matrix(0, nrow=f2, ncol=k+1)
  Zi2[index_z, 1:k] <- rmnom(n, 1, aux_rate)   #�������z����g�s�b�N���T���v�����O
  Zi2[-index_z, k+1] <- 1
  z2_vec <- as.numeric(Zi2 %*% 1:(k+1))
  
  
  ##�^�O�g�s�b�N�̃p�����[�^���X�V
  af <- as.matrix(t(aux_dt %*% Zi2[, 1:k])) + beta02   #�f�B�N�������z�̃p�����[�^
  omega <- extraDistr::rdirichlet(k, af)   #�p�����[�^���T���v�����O
  
  ##���e�Ɋ֌W�̂Ȃ��^�O�̃p�����[�^�̍X�V
  nf <- as.numeric(aux_dt %*% Zi2[, k+1]) + beta02   #�f�B�N�������z�̃p�����[�^
  gamma <- as.numeric(extraDistr::rdirichlet(1, nf))   #�p�����[�^���T���v�����O
  
  
  ##�p�����[�^�̊i�[�ƃT���v�����O���ʂ̕\��
  #�T���v�����O���ꂽ�p�����[�^���i�[
  if(rp%%keep==0){
    #�T���v�����O���ʂ̊i�[
    mkeep <- rp/keep
    THETA[, , mkeep] <- theta
    PHI[, , mkeep] <- phi
    OMEGA[, , mkeep] <- omega
    GAMMA[mkeep, ] <- gamma
    LAMBDA[mkeep] <- r
    
    #�g�s�b�N�����̓o�[���C�����Ԃ𒴂�����i�[����
    if(rp%%keep==0 & rp >= burnin){
      W_SEG <- W_SEG + Zi1
      A_SEG <- A_SEG + Zi2
      Z_SEG <- Z_SEG + z
    }
  }
  
  if(rp%%disp==0){
    #�ΐ��ޓx�̌v�Z
    LL1 <- sum(log(word_par$Bur %*% vec_k))
    LL2 <- sum(log(aux_par[index_z, ] %*% vec_k)) + sum(log(gamma[ad[-index_z]]))
    LL <- LL1 + LL2
    
    #�T���v�����O���ʂ��m�F
    print(rp)
    print(c(LL, LLst, LL1, LL2, LLst1, LLst2))
    print(round(c(r, r0[1]), 3))
    print(round(cbind(omega[, (a1-4):(a1+5)], omegat[, (a1-4):(a1+5)]), 3))
    print(round(rbind(gamma[(a1-9):(a1+10)], gammat[(a1-9):(a1+10)]), 3))
  }
}


####�T���v�����O���ʂ̉����Ɨv��####
burnin <- 500   #�o�[���C������

##�T���v�����O���ʂ̉���
#�����̃g�s�b�N���z�̃T���v�����O����
matplot(t(THETA[1, , ]), type="l", ylab="�p�����[�^", main="����1�̃g�s�b�N���z�̃T���v�����O����")
matplot(t(THETA[2, , ]), type="l", ylab="�p�����[�^", main="����2�̃g�s�b�N���z�̃T���v�����O����")
matplot(t(THETA[3, , ]), type="l", ylab="�p�����[�^", main="����3�̃g�s�b�N���z�̃T���v�����O����")
matplot(t(THETA[4, , ]), type="l", ylab="�p�����[�^", main="����4�̃g�s�b�N���z�̃T���v�����O����")

#�P��̏o���m���̃T���v�����O����
matplot(t(PHI[1, , ]), type="l", ylab="�p�����[�^", main="�g�s�b�N1�̒P��̏o�����̃T���v�����O����")
matplot(t(PHI[2, , ]), type="l", ylab="�p�����[�^", main="�g�s�b�N2�̒P��̏o�����̃T���v�����O����")
matplot(t(PHI[3, , ]), type="l", ylab="�p�����[�^", main="�g�s�b�N3�̒P��̏o�����̃T���v�����O����")
matplot(t(PHI[4, , ]), type="l", ylab="�p�����[�^", main="�g�s�b�N4�̒P��̏o�����̃T���v�����O����")
matplot(t(PHI[5, , ]), type="l", ylab="�p�����[�^", main="�g�s�b�N5�̒P��̏o�����̃T���v�����O����")
matplot(t(PHI[6, , ]), type="l", ylab="�p�����[�^", main="�g�s�b�N6�̒P��̏o�����̃T���v�����O����")
matplot(t(PHI[7, , ]), type="l", ylab="�p�����[�^", main="�g�s�b�N7�̒P��̏o�����̃T���v�����O����")
matplot(t(PHI[8, , ]), type="l", ylab="�p�����[�^", main="�g�s�b�N8�̒P��̏o�����̃T���v�����O����")

#�^�O�̏o���m���̃T���v�����O����
matplot(t(OMEGA[1, , ]), type="l", ylab="�p�����[�^", main="�g�s�b�N1�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����")
matplot(t(OMEGA[2, , ]), type="l", ylab="�p�����[�^", main="�g�s�b�N2�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����")
matplot(t(OMEGA[3, , ]), type="l", ylab="�p�����[�^", main="�g�s�b�N3�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����")
matplot(t(OMEGA[4, , ]), type="l", ylab="�p�����[�^", main="�g�s�b�N4�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����")
matplot(t(OMEGA[5, , ]), type="l", ylab="�p�����[�^", main="�g�s�b�N5�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����")
matplot(t(OMEGA[6, , ]), type="l", ylab="�p�����[�^", main="�g�s�b�N6�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����")
matplot(t(OMEGA[7, , ]), type="l", ylab="�p�����[�^", main="�g�s�b�N7�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����")
matplot(t(OMEGA[8, , ]), type="l", ylab="�p�����[�^", main="�g�s�b�N8�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����")
matplot(GAMMA, type="l", ylab="�p�����[�^", main="�g�s�b�N�Ɩ��֌W�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����")


##�T���v�����O���ʂ̗v�񐄒��
#�g�s�b�N���z�̎��㐄���
topic_mu <- apply(THETA[, , burnin:(R/keep)], c(1, 2), mean)   #�g�s�b�N���z�̎��㕽��
round(cbind(topic_mu, thetat), 3)
round(topic_sd <- apply(THETA[, , burnin:(R/keep)], c(1, 2), sd), 3)   #�g�s�b�N���z�̎���W���΍�

#�P��o���m���̎��㐄���
word_mu <- apply(PHI[, , burnin:(R/keep)], c(1, 2), mean)   #�P��̏o�����̎��㕽��
round(rbind(word_mu, phit)[, 1:50], 3)

#�^�O�o�����̎��㐄���
tag_mu1 <- apply(OMEGA[, , burnin:(R/keep)], c(1, 2), mean)   #�^�O�̏o�����̎��㕽��
round(rbind(tag_mu1, omegat), 3)

#�g�s�b�N�Ɩ��֌W�̃^�O�̎��㐄���
round(rbind(colMeans(GAMMA[burnin:(R/keep), ]), gammat), 3) #���֌W�^�O�̎��㕽��