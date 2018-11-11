#####�Ή�����g�s�b�N���f��#####
library(MASS)
library(lda)
library(RMeCab)
library(matrixStats)
library(Matrix)
library(bayesm)
library(HMM)
library(extraDistr)
library(reshape2)
library(dplyr)
library(plyr)
library(ggplot2)

#set.seed(93441)

####�f�[�^�̔���####
##�����̐ݒ�
k1 <- 10   #�����̃g�s�b�N��
k2 <- 15   #�����ƌ`�e���̃g�s�b�N��
d <- 2000   #������
v1 <- 1000   #�����̌�b��
v2 <- 500   #����(�`�e��)�̌�b��
s0 <- rpois(d, rgamma(d, 22.5, 0.5))   #�����Ɩ����̃y�A��
s1 <- extraDistr::rtpois(sum(s0), 4.0, a=0, b=Inf)   #�y�A���Ƃ̖�����
s2 <- extraDistr::rtpois(sum(s0), 0.7, a=0, b=3)   #�y�A���Ƃ̓�����
f0 <- sum(s0)   #�����͐�
f1 <- sum(s1)   #�����̑��P�ꐔ
f2 <- sum(s2)   #�����̑��P�ꐔ


##ID��ݒ�
p_id <- rep(1:d, s0)
w <- as.numeric(tapply(s1, p_id, sum))   #�P�ꐔ
w_id <- rep(1:d, w)
w_id1 <- rep(1:f0, s1)
w_id2 <- rep(1:f0, s2)


##���f���Ɋ�Â��P��𐶐�
#�f�B���N�����z�̃p�����[�^
alpha01 <- rep(0.1, k1)   #�g�s�b�N���z�̃p�����[�^
alpha02 <- rep(0.05, k2)   #�������f���̃p�����[�^
beta01 <- rep(0.1, v1)   #�����̒P�ꕪ�z�̃p�����[�^
beta02 <- rep(0.1, v2)   #�����̒P�ꕪ�z�̃p�����[�^

#�p�����[�^�𐶐�
theta1 <- thetat1 <- extraDistr::rdirichlet(d, alpha01)
beta <- betat <- matrix(rgamma(k1*k2, 0.25, 0.5), nrow=k1, ncol=k2)
phi <- phit <- extraDistr::rdirichlet(k1, beta01)
psi <- psit <- extraDistr::rdirichlet(k2, beta02)

#�����I�Ƀg�s�b�N�ƒP��𐶐�
WX1 <- matrix(0, nrow=f0, ncol=v1)
WX2 <- matrix(0, nrow=f0, ncol=v2)
word_list1 <- list()
word_list2 <- list()
Z_list1 <- list()
Z_list2 <- list()
Z_sums <- matrix(0, nrow=k2, ncol=k1)
Pr <- matrix(0, nrow=f0, ncol=k2)

for(i in 1:f0){
  if(i%%1000==0){
    print(i)
  }
  #�����g�s�b�N�𐶐�
  pr1 <- theta1[p_id[i], ]
  z1 <- rmnom(s1[i], 1, pr1)
  z1_vec <- as.numeric(z1 %*% 1:k1)

  #�����g�s�b�N�𐶐�
  U <- exp(colSums(z1) %*% beta)
  pr2 <- U / sum(U)
  z2 <- rmnom(s2[i], 1, pr2)
  z2_vec <- as.numeric(z2 %*% 1:k2)

  #�g�s�b�N�ɂ��ƂÂ��P��𐶐�
  word1 <- rmnom(s1[i], 1, phi[z1_vec, ])
  word2 <- rmnom(s2[i], 1, psi[z2_vec, ])

  #�f�[�^���i�[
  Z_list1[[i]] <- z1
  Z_list2[[i]] <- z2
  WX1[i, ] <- colSums(word1)
  WX2[i, ] <- colSums(word2)
  word_list1[[i]] <- as.numeric(word1 %*% 1:v1)
  word_list2[[i]] <- as.numeric(word2 %*% 1:v2)
  
  #theta2�𐄒�̂��߂Ƀg�s�b�N���i�[
  for(j in 1:s2[i]){
    Z_sums[z2_vec[j], ] <- Z_sums[z2_vec[j], ] + colSums(z1)
  }
  Pr[i, ] <- pr2
}

#���X�g��ϊ�
Z1 <- do.call(rbind, Z_list1)
Z2 <- do.call(rbind, Z_list2)
word_vec1 <- unlist(word_list1)
word_vec2 <- unlist(word_list2)

#�����̃g�s�b�N���z�𐶐�
theta2 <- thetat2 <- extraDistr::rdirichlet(k2, Z_sums + 0.01)


####�}���R�t�A�������e�J�����@�őΉ�����g�s�b�N���f���𐄒�####
##�P�ꂲ�Ƃɖޓx�ƕ��S�����v�Z����֐�
burden_fr <- function(theta, phi, wd, w, k){
  #���S�W�����v�Z
  Bur <- theta[w, ] * t(phi)[wd, ]   #�ޓx
  Br <- Bur / rowSums(Bur)   #���S��
  r <- colSums(Br) / sum(Br)   #������
  bval <- list(Br=Br, Bur=Bur, r=r)
  return(bval)
}

##�A���S���Y���̐ݒ�
R <- 5000
keep <- 2  
iter <- 0
burnin <- 1000/keep
disp <- 10

##�C���f�b�N�X���쐬
doc_list <- list()
doc_vec <- list()
w_list1 <- list()
w_vec1 <- list()
w_list2 <- list()
w_vec2 <- list()
pair_list <- list()
pair_vec <- list()

for(i in 1:d){
  doc_list[[i]] <- which(w_id==i)
  doc_vec[[i]] <- rep(1, length(doc_list[[i]]))
}
for(j in 1:v1){
  w_list1[[j]] <- which(word_vec1==j)
  w_vec1[[j]] <- rep(1, length(w_list1[[j]]))
}
for(j in 1:v2){
  w_list2[[j]] <- which(word_vec2==j)
  w_vec2[[j]] <- rep(1, length(w_list2[[j]]))
}
for(i in 1:f0){
  if(i%%1000==0){print(i)}
  pair_list[[i]] <- which(w_id1==i)
  pair_vec[[i]] <- rep(1, length(pair_list[[i]]))
}

##�y�AID���쐬
pair_id_list1 <- list()
for(i in 1:f0){
  pair_id_list1[[i]] <- rep(pair_list[[i]], s2[i])
}
pair_id1 <- unlist(pair_id_list1)
pair_id2 <- rep(1:f2, rep(s1, s2))


##�p�����[�^�̎��O���z
alpha01 <- 1
alpha02 <- 1
beta01 <- 0.1
beta02 <- 0.1

##�p�����[�^�̐^�l
theta1 <- thetat1
theta2 <- thetat2
phi <- phit
psi <- psit

##�p�����[�^�̏����l
theta1 <- extraDistr::rdirichlet(d, rep(1, k1))
theta2 <- extraDistr::rdirichlet(k2, rep(1, k1))
phi <- extraDistr::rdirichlet(k1, rep(1, v1))
psi <- extraDistr::rdirichlet(k2, rep(1, v2))

##�p�����[�^�̊i�[�p�z��
THETA1 <- array(0, dim=c(d, k1, R/keep))
THETA2 <- array(0, dim=c(k1, k2, R/keep))
PHI <- array(0, dim=c(k1, v1, R/keep))
PSI <- array(0, dim=c(k2, v2, R/keep))
SEG1 <- matrix(0, nrow=f1, ncol=k1)
SEG2 <- matrix(0, nrow=f2, ncol=k2)
LLho <- rep(0, R/keep)

##�ΐ��ޓx�̊�l
LLst1 <- sum(WX1 %*% log((colSums(WX1)+0.1) / (sum(WX1)+0.1*v1)))
LLst2 <- sum(WX2 %*% log((colSums(WX2)+0.1) / (sum(WX2)+0.1*v2)))
LLst <- LLst1 + LLst2


####�}���R�t�A�������e�J�����@�Ńp�����[�^���T���v�����O####
for(rp in 1:R){
  
  ##�����g�s�b�N���T���v�����O
  #���݃g�s�b�N�̃p�����[�^�𐄒�
  par1 <- burden_fr(theta1, phi, word_vec1, w_id, k1)
  z1_rate <- par1$Br
  
  #�������z���g�s�b�N���T���v�����O
  Zi1 <- rmnom(f1, 1, z1_rate)
  z1_vec <- as.numeric(Zi1 %*% 1:k1)
  Zi1_T <- t(Zi1)
  
  
  ##�p�����[�^���X�V
  #�g�s�b�N���z�̃p�����[�^���X�V
  wsum0 <- matrix(0, nrow=d, ncol=k1)
  for(i in 1:d){
    wsum0[i, ] <- Zi1_T[, doc_list[[i]]] %*% doc_vec[[i]]
  }
  wsum <- wsum0 + alpha01   #�f�B���N�����z�̃p�����[�^
  theta1 <- extraDistr::rdirichlet(d, wsum)   #�f�B���N�����z����p�����[�^���T���v�����O
  
  #�P�ꕪ�z�̃p�����[�^���X�V
  vsum0 <- matrix(0, nrow=k1, ncol=v1)
  for(j in 1:v1){
    vsum0[, j] <- Zi1_T[, w_list1[[j]], drop=FALSE] %*% w_vec1[[j]]
  }
  vsum <- vsum0 + beta01   #�f�B���N�����z�̃p�����[�^
  phi <- extraDistr::rdirichlet(k1, vsum)   #�f�B���N�����z����p�����[�^���T���v�����O
  
  
  ##�����̃g�s�b�N���T���v�����O
  #�������������g�s�b�N����g�s�b�N���z�𐄒�
  topic_par <- matrix(0, nrow=f0, ncol=k2)
  par2 <- t(t(log(theta2))[z1_vec, ])
  for(i in 1:f0){
    topic_par[i, ] <- par2[, pair_list[[i]], drop=FALSE] %*% pair_vec[[i]]   #�g�s�b�N���z�̑ΐ��ޓx
  }
  
  word_par <- t(log(psi))[word_vec2, ]   #�P��o�����̑ΐ��ޓx
  LLi0 <- topic_par[w_id2, ] + word_par   #�y�A���Ƃ̑ΐ��ޓx
  LLi <- exp(LLi0 - rowMaxs(LLi0))   #�ޓx�ɕϊ�
  
  #�������z�����ݕϐ�z���T���v�����O
  z2_rate <- LLi / rowSums(LLi)   #���ݕϐ�z�̊����m��
  Zi2 <- rmnom(f2, 1, z2_rate)   #�������z�����ݕϐ�z���T���v�����O
  z2_vec <- as.numeric(Zi2 %*% 1:k2)
  Zi2_T <- t(Zi2)
  
  
  ##�p�����[�^���X�V
  #�g�s�b�N���z�̃p�����[�^���X�V
  pair_sums0 <- Zi2_T[, pair_id2] %*% Zi1[pair_id1, ]
  pair_sums <- pair_sums0 + alpha02   #�f�B���N�����z�̃p�����[�^
  theta2 <- extraDistr::rdirichlet(k2, pair_sums)   #�f�B���N�����z����p�����[�^���T���v�����O
  
  
  #�P�ꕪ�z�̃p�����[�^���X�V
  tsum0 <- matrix(0, nrow=k2, ncol=v2)
  for(j in 1:v2){
    tsum0[, j] <- Zi2_T[, w_list2[[j]], drop=FALSE] %*% w_vec2[[j]]
  }
  tsum <- tsum0 + beta02   #�f�B���N�����z�̃p�����[�^
  psi <- extraDistr::rdirichlet(k2, tsum)   #�f�B���N�����z����p�����[�^���T���v�����O

  
  ##�p�����[�^�̊i�[�ƃT���v�����O���ʂ̕\��
  #�T���v�����O���ꂽ�p�����[�^���i�[
  if(rp%%keep==0){
    #�T���v�����O���ʂ̊i�[
    mkeep <- rp/keep
    THETA1[, , mkeep] <- theta1
    THETA2[, , mkeep] <- theta2
    PHI[, , mkeep] <- phi
    PSI[, , mkeep] <- psi
    
    #�g�s�b�N�����̓o�[���C�����Ԃ𒴂�����i�[����
    if(rp%%keep==0 & rp >= burnin){
      SEG1 <- SEG1 + Zi1
      SEG2 <- SEG2 + Zi2
    }
    
    #�T���v�����O���ʂ��m�F
    if(rp%%disp==0){
      LL1 <- sum(log(rowSums(par1$Bur)))
      LL2 <- sum(log(rowSums(exp(word_par) * Zi2)))
      LL <- LL1 + LL2   #�ΐ��ޓx
      print(rp)
      print(c(LL, LLst, LL1, LLst1, LL2, LLst2))
      print(round(rbind(theta1[1:5, ], thetat1[1:5, ]), 3))
      print(round(cbind(psi[, 1:10], psit[, 1:10]), 3))
    }
  }
}

####�T���v�����O���ʂ̉����Ɨv��####
burnin <- 1000/keep   #�o�[���C������
RS <- R/keep

##�T���v�����O���ʂ̉���
#�����̃g�s�b�N���z�̉���
matplot(t(THETA1[1, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA1[2, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA1[3, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA1[4, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA1[5, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")

#�����̒P�ꕪ�z�̉���
matplot(t(PHI[1, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(PHI[2, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(PHI[3, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(PHI[4, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(PHI[5, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")

#���ʊK�w�̃g�s�b�N���z�̉���
matplot(t(THETA2[1, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA2[3, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA2[5, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA2[10, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA2[15, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
        
#���ʊK�w�̒P�ꕪ�z�̉���
matplot(t(PSI[1, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(PSI[2, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(PSI[3, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(PSI[4, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(PSI[5, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(PSI[6, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")

##�T���v�����O���ʂ̗v�񐄒��
#�g�s�b�N�����̎��㕪�z�̗v��
seg_rate1 <- SEG1 / rowSums(SEG1)
seg_rate2 <- SEG2 / rowSums(SEG2)
cbind(Z1 %*% 1:k1, round(SEG1 / rowSums(SEG1), 3))   #�����g�s�b�N�̊���
cbind(Z2 %*% 1:k2, round(SEG2 / rowSums(SEG2), 3))   #�����g�s�b�N�̊���

#�����Ɩ����g�s�b�N�̊֘A
word_theta0 <- matrix(0, nrow=v2, ncol=k1)
for(j in 1:k1){
  word_theta0[, j] <- tapply(seg_rate1[pair_id1, j], word_vec2[pair_id2], sum)
}
round(word_theta <- word_theta0 / rowSums(word_theta0), 3)


#�����g�s�b�N���z�̎��㐄���
topic_mu1 <- apply(THETA1[, , burnin:(R/keep)], c(1, 2), mean)   #�g�s�b�N���z�̎��㕽��
round(cbind(topic_mu1, thetat1), 3)
round(topic_sd1 <- apply(THETA1[, , burnin:(R/keep)], c(1, 2), sd), 3)   #�g�s�b�N���z�̎���W���΍�

#�P�ꊄ���̎��㐄���
word_mu1 <- apply(PHI[, , burnin:(R/keep)], c(1, 2), mean)   #�P��̏o�����̎��㕽��
round(t(rbind(word_mu1, phit)), 3)

#�����g�s�b�N���z�̎��㐄���
topic_mu2 <- apply(THETA2[, , burnin:(R/keep)], c(1, 2), mean)   #�g�s�b�N���z�̎��㕽��
round(rbind(topic_mu2, thetat2), 3)
round(topic_sd2 <- apply(THETA2[, , burnin:(R/keep)], c(1, 2), sd), 3)   #�g�s�b�N���z�̎���W���΍�

#���ʊK�w�̒P��o���m���̎��㐄���
word_mu2 <- apply(PSI[, , burnin:(R/keep)], c(1, 2), mean)   #�P��̏o�����̎��㕽��
round(cbind(t(word_mu2), t(psit)), 3)



