#####Latent Dirichlet Allocation���f��(������)#####
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

#set.seed(21437)

####�f�[�^�̔���####
#set.seed(423943)
#�f�[�^�̐ݒ�
k <- 15   #�g�s�b�N��
d <- 3000   #������
v <- 1000   #��b��
w <- rpois(d, rgamma(d, 60, 0.50))   #1����������̒P�ꐔ
f <- sum(w)
vec <- rep(1, k)

#ID�̐ݒ�
d_id <- rep(1:d, w)

#�p�����[�^�̐ݒ�
alpha01 <- rep(0.15, k)   #�����̃f�B���N�����O���z�̃p�����[�^
alpha02 <- rep(0.1, v)   #�P��̃f�B���N�����O���z�̃p�����[�^

##���ׂĂ̒P�ꂪ���������܂ŌJ��Ԃ�
for(rp in 1:1000) {
  print(rp)
  
  #�f�B���N�������̔���
  thetat <- theta <- rdirichlet(d, alpha01)   #�����̃g�s�b�N���z���f�B���N���������甭��
  phit <- phi <- rdirichlet(k, alpha02)   #�P��̃g�s�b�N���z���f�B���N���������甭��
  
  #�������z�̗�������f�[�^�𔭐�
  WX <- matrix(0, nrow=d, ncol=v)
  wd_list <- Z<- list() 
  
  for(i in 1:d){
    #�g�s�b�N�𐶐�
    z <- rmnom(w[i], 1, theta[i, ])   #�����̃g�s�b�N���z�𔭐�
    z_vec <- z %*% c(1:k)   #�g�s�b�N�������x�N�g����
    
    #�P��𐶐�
    wx <- rmnom(w[i], 1, phi[z_vec, ])   #�����̃g�s�b�N�J���P��𐶐�
    wd_list[[i]] <- as.numeric(wx %*% 1:v)   #�P��x�N�g�����i�[
    WX[i, ] <- colSums(wx)   #�P�ꂲ�Ƃɍ��v����1�s�ɂ܂Ƃ߂�
    Z[[i]] <- z
  }
  if(min(colSums(WX)) > 0) break
}

#���X�g���x�N�g���ɕϊ�
wd <- unlist(wd_list)
sparse_data <- sparseMatrix(i=1:f, wd, x=rep(1, f), dims=c(f, v))
sparse_data_T <- t(sparse_data)


####�}���R�t�A�������e�J�����@�őΉ��g�s�b�N���f���𐄒�####
##�P�ꂲ�Ƃɖޓx�ƕ��S�����v�Z����֐�
burden_fr <- function(theta, phi, wd, d_id, k, vec){
  
  #���S�W�����v�Z
  Bur <- theta[d_id, ] * t(phi)[wd, ]   #�ޓx
  Br <- Bur / as.numeric(Bur %*% vec)   #���S���̌v�Z
  bval <- list(Br=Br, Bur=Bur)
  return(bval)
}

##�A���S���Y���̐ݒ�
R <- 2000   #�T���v�����O��
keep <- 2   #2���1��̊����ŃT���v�����O���ʂ��i�[
disp <- 20
iter <- 0
burnin <- 200/keep

##�f�[�^�̐ݒ�
d_vec <- sparseMatrix(sort(d_id), 1:f, x=rep(1, f), dims=c(d, f))


##���O���z�̐ݒ�
#�n�C�p�[�p�����[�^�̎��O���z
alpha01 <- 0.1
alpha02 <- 0.1


##�p�����[�^�̏����l
theta <- extraDistr::rdirichlet(d, rep(1, k))   #�����g�s�b�N�̃p�����[�^�̏����l
phi <- extraDistr::rdirichlet(k, rep(1, v))    #�P��g�s�b�N�̃p�����[�^�̏����l

##�p�����[�^�̊i�[�p�z��
THETA <- array(0, dim=c(d, k, R/keep))
PHI <- array(0, dim=c(k, v, R/keep))
SEG <- matrix(0, nrow=f, ncol=k)
storage.mode(SEG) <- "integer"
gc(); gc()


##�ΐ��ޓx�̊�l
LLst <- sum(sparse_data %*% log(colSums(WX) / sum(WX)))


####�M�u�X�T���v�����O�Ńp�����[�^���T���v�����O####
for(rp in 1:R){
  
  ##�P��g�s�b�N���T���v�����O
  #�P�ꂲ�ƂɃg�s�b�N�̏o�������v�Z
  word_par <- burden_fr(theta, phi, wd, d_id, k, vec)
  word_rate <- word_par$Br
  
  #�������z����P��g�s�b�N���T���v�����O
  Zi <- rmnom(f, 1, word_rate)   
  
  
  ##�P��g�s�b�N�̃p�����[�^���X�V
  #�f�B�N�������z����theta���T���v�����O
  wsum <- d_vec %*% Zi + alpha01
  theta <- extraDistr::rdirichlet(d, wsum)
  
  #�f�B�N�������z����phi���T���v�����O
  vsum <- t(sparse_data_T %*% Zi) + alpha02
  phi <- extraDistr::rdirichlet(k, vsum)
  
  
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
  
  #�ΐ��ޓx�ƃT���v�����O���ʂ��m�F
  if(rp%%disp==0){
    #�g�s�b�N���f���̑ΐ��ޓx
    LL <- sum(log((theta[d_id, ] * t(phi)[wd, ]) %*% vec))
    
    #�T���v�����O���ʂ�\��
    print(rp)
    print(c(LL, LLst))
    print(round(cbind(phi[, 1:10], phit[, 1:10]), 3))
  }
}

####�T���v�����O���ʂ̉����Ɨv��####
burnin <- 200/keep   #�o�[���C������
RS <- R/keep

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

##�T���v�����O���ʂ̗v�񐄒��
#�g�s�b�N���z�̎��㐄���
topic_mu <- apply(THETA[, , burnin:(R/keep)], c(1, 2), mean)   #�g�s�b�N���z�̎��㕽��
round(cbind(topic_mu, thetat), 3)
round(topic_sd <- apply(THETA[, , burnin:(R/keep)], c(1, 2), sd), 3)   #�g�s�b�N���z�̎���W���΍�

#�P��o���m���̎��㐄���
word_mu <- apply(PHI[, , burnin:(R/keep)], c(1, 2), mean)   #�P��̏o�����̎��㕽��
round(rbind(word_mu, phit)[, 1:50], 3)