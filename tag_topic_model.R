#####�^�O�����g�s�b�N���f��#####
library(MASS)
library(lda)
library(RMeCab)
library(matrixStats)
library(Matrix)
library(bayesm)
library(extraDistr)
library(reshape2)
library(dplyr)
library(plyr)
library(ggplot2)

#set.seed(8079)

####�f�[�^�̔���####
#set.seed(423943)
#�����f�[�^�̐ݒ�
k <- 8   #�g�s�b�N��
d <- 1500   #������
v <- 300   #��b��
w <- rpois(d, 160)   #1����������̒P�ꐔ
f <- sum(w)   #���P�ꐔ
a <- 75   #�^�O��
x0 <- rpois(d, 15)
x <- ifelse(x0 < 1, 1, x0)
e <- sum(x)
 
#ID�̐ݒ�
word_id <- rep(1:d, w)
aux_id <- rep(1:d, x)

#�p�����[�^�̐ݒ�
alpha0 <- rep(0.2, k)   #�����̃f�B���N�����O���z�̃p�����[�^
alpha1 <- rep(0.25, a)   #�^�O�̃f�B���N�����O���z�̃p�����[��
alpha2 <- rep(0.025, v)   #�P��̃f�B���N�����O���z�̃p�����[�^

#�f�B���N�������̔���
thetat <- theta <- extraDistr::rdirichlet(d, alpha0)   #�����̃g�s�b�N���z���f�B���N���������甭��
gammat <- gamma <- extraDistr::rdirichlet(k, alpha1)   #�^�O�̃g�s�b�N���z���f�B���N���������甭��
phit <- phi <- extraDistr::rdirichlet(a, alpha2)   #�P��̃g�s�b�N���z���f�B���N���������甭��


##�������z����g�s�b�N����ђP��f�[�^�𔭐�
WX <- matrix(0, nrow=d, ncol=v)
AX <- matrix(0, nrow=d, ncol=a)
z0 <- rep(0, sum(x)) 
Z1 <- list()
Z2 <- list()

#�������ƂɃg�s�b�N�ƒP��𒀎�����
for(i in 1:d){
  print(i)
  
  #�����̃g�s�b�N���z�𔭐�
  z <- rmnom(x[i], 1, theta[i, ])   #�����̃g�s�b�N���z�𔭐�
  
  #�����̃g�s�b�N���z����^�O�𔭐�
  zd <- as.numeric(z %*% 1:k)   #0,1�𐔒l�ɒu��������
  
  an <- rmnom(x[i], 1, gamma[zd, ])   #�����̃g�s�b�N����^�O�𐶐�
  ad <- colSums(an)   #�P�ꂲ�Ƃɍ��v����1�s�ɂ܂Ƃ߂�
  AX[i, ] <- ad
  
  #�������ꂽ�^�O����P��𐶐�
  share <- rep(1:a, colSums(rmnom(w[i], 1, ad)))
  wn <- rmnom(w[i], 1, phi[share, ])   #�������z����P��𐶐�
  wd <- colSums(wn)
  WX[i, ] <- wd
}

#�f�[�^�s��𐮐��^�s��ɕύX
storage.mode(WX) <- "integer"
storage.mode(AX) <- "integer"


####�g�s�b�N���f������̂��߂̃f�[�^�Ɗ֐��̏���####
##���ꂼ��̕������̒P��̏o������ѕ⏕���̏o�����x�N�g���ɕ��ׂ�
##�f�[�^����pID���쐬
ID1_list <- list()
wd_list <- list()
ID2_list <- list()
ad_list <- list()

#���l���Ƃɋ��lID����ђP��ID���쐬
for(i in 1:nrow(WX)){
  print(i)
  
  #�P���ID�x�N�g�����쐬
  ID1_list[[i]] <- rep(i, w[i])
  num1 <- (WX[i, ] > 0) * (1:v)
  num2 <- which(num1 > 0)
  W1 <- WX[i, (WX[i, ] > 0)]
  number <- rep(num2, W1)
  wd_list[[i]] <- number
  
  #�⏕����ID�x�N�g�����쐬
  ID2_list[[i]] <- rep(i, x[i])
  num1 <- (AX[i, ] > 0) * (1:a)
  num2 <- which(num1 > 0)
  A1 <- AX[i, (AX[i, ] > 0)]
  number <- rep(num2, A1)
  ad_list[[i]] <- number
}

#���X�g���x�N�g���ɕϊ�
ID1_d <- unlist(ID1_list)
ID2_d <- unlist(ID2_list)
wd <- unlist(wd_list)
ad <- unlist(ad_list)

##�C���f�b�N�X���쐬
doc1_list <- list()
word_list <- list()
doc2_list <- list()
aux_list <- list()
for(i in 1:length(unique(ID1_d))) {doc1_list[[i]] <- which(ID1_d==i)}
for(i in 1:length(unique(wd))) {word_list[[i]] <- which(wd==i)}
for(i in 1:length(unique(ID2_d))) {doc2_list[[i]] <- which(ID2_d==i)}
for(i in 1:length(unique(ad))) {aux_list[[i]] <- which(ad==i)}
gc(); gc()


####�}���R�t�A�������e�J�����@�őΉ��g�s�b�N���f���𐄒�####
##�P�ꂲ�Ƃɖޓx�ƕ��S�����v�Z����֐�
burden_fr <- function(theta, phi, wd, w, k){
  Bur <-  matrix(0, nrow=length(wd), ncol=k)   #���S�W���̊i�[�p
  for(j in 1:k){
    #���S�W�����v�Z
    Bi <- rep(theta[, j], w) * phi[j, wd]   #�ޓx
    Bur[, j] <- Bi   
  }
  
  Br <- Bur / rowSums(Bur)   #���S���̌v�Z
  r <- colSums(Br) / sum(Br)   #�������̌v�Z
  bval <- list(Br=Br, Bur=Bur, r=r)
  return(bval)
}

##�A���S���Y���̐ݒ�
R <- 10000   #�T���v�����O��
keep <- 2   #2���1��̊����ŃT���v�����O���ʂ��i�[
iter <- 0
burnin <- 1000/keep

##���O���z�̐ݒ�
#�n�C�p�[�p�����[�^�̎��O���z
alpha01 <- rep(1.0, k)
beta0 <- rep(0.5, v)
gamma0 <- rep(0.5, a)
alpha01m <- matrix(alpha01, nrow=d, ncol=k, byrow=T)
beta0m <- matrix(beta0, nrow=a, ncol=v)
gamma0m <- matrix(gamma0, nrow=k, ncol=a)
delta0m <- gamma0

##�p�����[�^�̏����l
#tfidf�ŏ����l��ݒ�
tf <- AX/rowSums(AX)
idf <- log(nrow(AX)/colSums(AX > 0))

theta <- rdirichlet(d, rep(1, k))   #�����g�s�b�N�̃p�����[�^�̏����l
gamma <- rdirichlet(k, idf)   #�^�O�g�s�b�N�̃p�����[�^�̏����l
phi <- rdirichlet(a, rep(10, v))   #�P��̏o�����̃p�����[�^�̏����l

##�p�����[�^�̊i�[�p�z��
THETA <- array(0, dim=c(d, k, R/keep))
PHI <- array(0, dim=c(a, v, R/keep))
GAMMA <- array(0, dim=c(k, a, R/keep))
W_SEG <- matrix(0, nrow=f, ncol=a)
A_SEG <- matrix(0, nrow=f, ncol=k)
storage.mode(W_SEG) <- "integer"
storage.mode(A_SEG) <- "integer"
gc(); gc()

##MCMC����p�z��
AXL <- AX[ID1_d, ]
tsum0 <- matrix(0, nrow=d, ncol=k)
vf0 <- matrix(0, nrow=k, ncol=a)
wf0 <- matrix(0, nrow=a, ncol=v)
af0 <- matrix(0, nrow=a, ncol=k)
aux_z <- rep(0, length(ad))


####�M�u�X�T���v�����O�Ńp�����[�^���T���v�����O####
for(rp in 1:R){
  
  ##���������^�O����P����T���v�����O
  #�P��𐶐�������݃^�O���T���v�����O
  word_bur <- t(phi)[wd, ] * AXL
  word_rate <- word_bur/rowSums(word_bur)
  Zi1 <- rmnom(f, 1, word_rate)
  Zi1[is.na(Zi1)] <- 0
  z_vec1 <- as.numeric(Zi1 %*% 1:a)
  
  #���݃^�O����P��o�������T���v�����O
  for(j in 1:v){
    wf0[, j] <- colSums(Zi1[wd_list[[j]], ])
  }
  wf <- wf0 + beta0m
  phi <- extraDistr::rdirichlet(a, wf)

  
  ##�^�O�g�s�b�N���T���v�����O
  #�^�O���ƂɃg�s�b�N�̏o�������v�Z
  tag_rate <- burden_fr(theta, gamma, z_vec1, w, k)$Br

  #�������z����P��g�s�b�N���T���v�����O
  Zi2 <- rmnom(f, 1, tag_rate)   
  z_vec2 <- Zi2 %*% 1:k

  ##�����g�s�b�N�̃p�����[�^���X�V
  #�f�B�N�������z����theta���T���v�����O
  for(i in 1:d){
    tsum0[i, ] <- colSums(Zi2[doc1_list[[i]], ])
  }
  tsum <- tsum0 + alpha01m 
  theta <- extraDistr::rdirichlet(d, tsum)

  #�f�B�N�������z����^�Ophi���T���v�����O
  for(j in 1:a){
    vf0[, j] <- colSums(Zi2[z_vec1==j, , drop=FALSE])
  }
  vf <- vf0 + gamma0m
  gamma <- extraDistr::rdirichlet(k, vf)
  
  ##�p�����[�^�̊i�[�ƃT���v�����O���ʂ̕\��
  #�T���v�����O���ꂽ�p�����[�^���i�[
  if(rp%%keep==0){
    #�T���v�����O���ʂ̊i�[
    mkeep <- rp/keep
    THETA[, , mkeep] <- theta
    PHI[, , mkeep] <- phi
    GAMMA[, , mkeep] <- gamma

    #�g�s�b�N�����̓o�[���C�����Ԃ𒴂�����i�[����
    if(rp >= burnin){
      A_SEG <- A_SEG + Zi2
      W_SEG <- W_SEG + Zi1
    }
    
    #�T���v�����O���ʂ��m�F
    print(rp)
    print(round(cbind(theta[1:10, ], thetat[1:10, ]), 3))
    print(round(cbind(gamma[, 1:10], gammat[, 1:10]), 3))
    #print(round(cbind(phi[1:8, 1:10], phit[1:8, 1:10]), 3))
  }
}

####�T���v�����O���ʂ̉����Ɨv��####
burnin <- 2000   #�o�[���C������

##�T���v�����O���ʂ̉���
#�����̃g�s�b�N���z�̃T���v�����O����
matplot(t(THETA[1, , ]), type="l", ylab="�p�����[�^", main="����1�̃g�s�b�N���z�̃T���v�����O����")
matplot(t(THETA[2, , ]), type="l", ylab="�p�����[�^", main="����2�̃g�s�b�N���z�̃T���v�����O����")
matplot(t(THETA[3, , ]), type="l", ylab="�p�����[�^", main="����3�̃g�s�b�N���z�̃T���v�����O����")
matplot(t(THETA[4, , ]), type="l", ylab="�p�����[�^", main="����4�̃g�s�b�N���z�̃T���v�����O����")

#�P��̏o���m���̃T���v�����O����
matplot(t(PHI[1, 1:10, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N1�̒P��̏o�����̃T���v�����O����")
matplot(t(PHI[2, 11:20, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N2�̒P��̏o�����̃T���v�����O����")
matplot(t(PHI[3, 21:30, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N3�̒P��̏o�����̃T���v�����O����")
matplot(t(PHI[4, 31:40, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N4�̒P��̏o�����̃T���v�����O����")
matplot(t(PHI[5, 41:50, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N5�̒P��̏o�����̃T���v�����O����")
matplot(t(PHI[6, 51:60, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N6�̒P��̏o�����̃T���v�����O����")
matplot(t(PHI[7, 61:70, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N7�̒P��̏o�����̃T���v�����O����")
matplot(t(PHI[8, 71:80, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N8�̒P��̏o�����̃T���v�����O����")

#�^�O�̏o���m���̃T���v�����O����
matplot(t(OMEGA[1, 1:10, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N1�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����")
matplot(t(OMEGA[2, 6:15, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N2�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����")
matplot(t(OMEGA[3, 16:25, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N3�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����")
matplot(t(OMEGA[4, 21:30, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N4�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����")
matplot(t(OMEGA[5, 26:35, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N5�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����")
matplot(t(OMEGA[6, 31:40, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N6�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����")
matplot(t(OMEGA[7, 36:45, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N7�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����")
matplot(t(OMEGA[8, 41:50, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N8�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����")
matplot(GAMMA[, 41:50], type="l", ylab="�p�����[�^", main="�g�s�b�N�Ɩ��֌W�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����1")
matplot(GAMMA[, 51:60], type="l", ylab="�p�����[�^", main="�g�s�b�N�Ɩ��֌W�̃^�O�̏o�����̃p�����[�^�̃T���v�����O����2")

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
round(rbind(colMeans(GAMMA[burnin:(R/keep), ]), gammat), 3)   #���֌W�^�O�̎��㕽��

