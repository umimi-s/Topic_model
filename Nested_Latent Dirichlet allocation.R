#####Nested Latent Dirichlet Allocation#####
options(warn=2)
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
##�f�[�^�̐ݒ�
L <- 3   #�K�w��
k1 <- 1   #���x��1�̊K�w��
k2 <- 4   #���x��2�̊K�w��
k3 <- rtpois(k2, 3, a=1, b=Inf)   #���x��3�̊K�w��
k <- sum(c(k1, k2, k3))   #���g�s�b�N��
d <- 2000   #������
v1 <- 300
v2 <- 300
v3 <- 400
v <- v1 + v2 + v3   #��b��
w <- rpois(d, rgamma(d, 85, 0.5))   #�P�ꐔ
f <- sum(w)   #�P�ꐔ


#ID��ݒ�
d_id <- rep(1:d, w)

##�f�[�^�̐���
for(rp in 1:1000){
  print(rp)
  
  #�f�B���N�����z�̃p�����[�^��ݒ�
  alpha1 <- alphat1 <- c(0.2, 0.25, 0.3)
  alpha2 <- alphat2 <- rep(10.0, k2)
  alpha3 <- alphat3 <- list()
  for(j in 1:k2){
    alpha3[[j]] <- alphat3[[j]] <- rep(3.0, k3[j])
  }
  beta1 <- c(rep(1.0, v1), rep(0.001, v2+v3))
  beta2 <- c(rep(0.0001, v1), rep(0.2, v2), rep(0.0001, v3))
  beta3 <- c(rep(0.0001, v1+v2), rep(0.15, v3))

  #�f�B���N�����z����p�����[�^�𐶐�
  theta1 <- thetat1 <- extraDistr::rdirichlet(d, alpha1)
  theta2 <- thetat2 <- as.numeric(extraDistr::rdirichlet(1, alpha2))
  theta3 <- thetat3 <- list()
  for(j in 1:k2){
    theta3[[j]] <- thetat3[[j]] <- as.numeric(extraDistr::rdirichlet(1, alpha3[[j]]))
  }
  phi1 <- phit1 <- as.numeric(extraDistr::rdirichlet(k1, beta1))
  phi2 <- phit2 <- extraDistr::rdirichlet(k2, beta2)
  phi3 <- phit3 <- list()
  for(j in 1:k2){
    phi3[[j]] <- phit3[[j]] <- extraDistr::rdirichlet(k3[j], beta3)
  }
  phi <- phit <- rbind(phi1, phi2, do.call(rbind, phi3))
  
  ##�����ߒ��Ɋ�Â��P��𐶐�
  Z1 <- matrix(0, nrow=d, ncol=L)
  Z1[, 1] <- 1
  Z12_list <- list()
  Z13_list <- list()
  Z2_list <- list()
  WX <- matrix(0, nrow=d, ncol=v)
  data_list <- list()
  word_list <- list()
  
  for(i in 1:d){
    #�m�[�h�𐶐�
    z12 <- rmnom(1, 1, theta2) 
    Z1[i, 2] <- as.numeric(z12 %*% 1:k2)
    z13 <- rmnom(1, 1, theta3[[Z1[i, 2]]])
    Z1[i, 3] <- as.numeric(z13 %*% 1:k3[Z1[i, 2]])
    
    #�g�s�b�N�̃��x���𐶐�
    z2 <- rmnom(w[i], 1, theta1[i, ])
    z2_vec <- as.numeric(z2 %*% 1:L)
    
    #���x�����ƂɒP��𐶐�
    index <- list()
    words <- matrix(0, nrow=w[i], ncol=v)
    for(j in 1:L){
      index[[j]] <- which(z2_vec==j)
    }
    words[index[[1]], ] <- rmnom(length(index[[1]]), 1, phi1)
    words[index[[2]], ] <- rmnom(length(index[[2]]), 1, phi2[Z1[i, 2], ])
    words[index[[3]], ] <- rmnom(length(index[[3]]), 1, phi3[[Z1[i, 2]]][Z1[i, 3], ])  
    
    
    #�f�[�^���i�[
    Z12_list[[i]] <- z12
    Z2_list[[i]] <- z2
    WX[i, ] <- colSums(words)
    data_list[[i]] <- words
    word_list[[i]] <- as.numeric(words %*% 1:v)
  }
  if(min(colSums(WX)) > 0) break
}

#���X�g��ϊ�
Z12 <- do.call(rbind, Z12_list)
Z2 <- do.call(rbind, Z2_list)
word_vec <- unlist(word_list)
Data <- do.call(rbind, data_list)
storage.mode(Data) <- "integer"
storage.mode(Z2) <- "integer"
storage.mode(WX) <- "integer"
sparse_wx <- as(WX, "CsparseMatrix")
sparse_data <- as(Data, "CsparseMatrix")
rm(data_list); rm(Z2_list); rm(word_list)
gc(); gc()


####�}���R�t�A�������e�J�����@��nCRP-LDA�𐄒�####
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


##���O���z�̐ݒ�
alpha1 <- 1
alpha2 <- 1
alpha3 <- 0.1
beta1 <- 1   #CRP�̎��O���z
beta2 <- 1

##�p�����[�^�̐^�l
#�g�s�b�N���f���̃p�����[�^�̐^�l
theta <- thetat1
phi1 <- phit1; phi2 <- phit2; phi3 <- phit3
phi2[phi2==0] <- 10^-100
for(j in 1:k2){
  phi3[[j]][phi3[[j]]==0] <- 10^-10
}
Zi2 <- Z2
Zi1 <- rmnom(d, 1, rep(1/sum(k3), sum(k3)))
Zi12 <- matrix(0, nrow=d, ncol=k2)
cumsum_k3 <- cumsum(k3)
index_z1 <- list()
for(j in 1:length(k3)){
  if(j==1){
    index_z1[[j]] <- 1:cumsum_k3[j]
  } else {
    index_z1[[j]] <- (cumsum_k3[j-1]+1):cumsum_k3[j]
  }
  Zi12[, j] <- rowSums(Zi1[, index_z1[[j]]])
}
r <- colMeans(Zi1)


#�p�����[�^�̏����l
theta <- extraDistr::rdirichlet(d, rep(10, L))
phi1 <- extraDistr::rdirichlet(k1, rep(100, v))
phi2 <- extraDistr::rdirichlet(k2, rep(100, v))
phi3 <- list()
for(j in 1:k2){
  phi3[[j]] <- extraDistr::rdirichlet(k3[j], rep(100.0, v))
}

#�g�s�b�N�����̏����l
Zi1 <- rmnom(d, 1, rep(1/sum(k3), sum(k3)))
Zi12 <- matrix(0, nrow=d, ncol=k2)
cumsum_k3 <- cumsum(k3)
index_z1 <- list()
for(j in 1:length(k3)){
  if(j==1){
    index_z1[[j]] <- 1:cumsum_k3[j]
  } else {
    index_z1[[j]] <- (cumsum_k3[j-1]+1):cumsum_k3[j]
  }
  Zi12[, j] <- rowSums(Zi1[, index_z1[[j]], drop=FALSE])
}
Zi2 <- rmnom(f, 1, rep(1/L, L))
r <- colMeans(Zi1)

##�p�����[�^�̊i�[�p�z��
THETA <- array(0, dim=c(d, L, R/keep))
PHI1 <- matrix(0, nrow=R/keep, ncol=v)
PHI2 <- array(0, dim=c(k2, v, R/keep))
PHI3 <- array(0, dim=c(ncol(Zi1), v, R/keep))
SEG1 <- matrix(0, nrow=d, ncol=ncol(Zi1))
SEG2 <- matrix(0, nrow=f, ncol=L)

##�C���f�b�N�X���쐬
doc_vec <- doc_list <- list()
for(i in 1:d){
  doc_list[[i]] <- which(d_id==i)
  doc_vec[[i]] <- rep(1, length(doc_list[[i]]))
}


####�M�u�X�T���v�����O�Ńp�����[�^���T���v�����O####
for(rp in 1:R){
  
  ##���x��2�̃p�X�̑ΐ��ޓx
  #�������Ƃɑΐ��ޓx��ݒ�
  LLho2 <- as.matrix(t((sparse_data * Zi2[, 2]) %*% t(log(phi2))))
  LLi2_T <- matrix(0, ncol=d, nrow=nrow(phi2))
  for(i in 1:d){
    LLi2_T[, i] <- LLho2[, doc_list[[i]]] %*% doc_vec[[i]]
  }
  LLi2 <- t(LLi2_T)
  Li2 <- exp(LLi2 - rowMaxs(LLi2))   #�ޓx�ɕϊ�

  
  ##���x��3�̃p�X�̑ΐ��ޓx
  LLi3 <- list()
  LLi_z <- cbind()
  
  #���x��2�̃p�X���ƂɃ��x��3�̃p�X�̑ΐ��ޓx��ݒ�
  for(j in 1:k2){
  
    #�������Ƃɑΐ��ޓx��ݒ�
    LLho3 <- as.matrix(t((sparse_data * Zi2[, 3]) %*% t(log(phi3[[j]]))))
    LLi3_T <- matrix(0, nrow=k3[j], ncol=d)
    for(i in 1:d){
      LLi3_T[, i] <- LLho3[, doc_list[[i]]] %*% doc_vec[[i]]
    }
    LLi3[[j]] <- t(LLi3_T)
    LLi_z <- cbind(LLi_z, LLi3[[j]] + LLi2[, j])   #�ΐ��ޓx�̘a
  }
  Li_z <- exp(LLi_z - rowMaxs(LLi_z))   #�ޓx�ɕϊ�

  
  #���ݕϐ�z�̊����m���̐����Z�̃T���v�����O
  gamma <- matrix(r, nrow=d, ncol=ncol(Zi1), byrow=T) * Li_z
  z1_rate <- gamma / rowSums(gamma)
  Zi1 <- rmnom(d, 1, z1_rate)
  
  #���x��2�̃g�s�b�N������ݒ�
  Zi12 <- matrix(0, nrow=d, ncol=k2)
  for(j in 1:k2){
    k3[j] <- length(index_z1[[j]])
    Zi12[, j] <- rowSums(Zi1[, index_z1[[j]], drop=FALSE])
  }
  
  #�������̍X�V
  r <- colMeans(Zi1)

  
  ##�p�X���ƂɒP�ꕪ�z�̃p�����[�^���X�V
  #���x��1�̒P�ꕪ�z���T���v�����O
  vsum11 <- colSums(sparse_data * Zi2[, 1]) + alpha3
  phi1 <- as.numeric(extraDistr::rdirichlet(1, vsum11))
  
  #���x��2�̒P�ꕪ�z���T���v�����O
  vsum12 <- as.matrix(t(Zi12[d_id, ]) %*% (sparse_data * Zi2[, 2])) + alpha3
  phi2 <- extraDistr::rdirichlet(nrow(vsum12), vsum12)
  
  #���x��3�̒P�ꕪ�z���T���v�����O
  phi3 <- list()
  for(j in 1:k2){
    vsum13 <- as.matrix(t(Zi1[d_id, index_z1[[j]], drop=FALSE]) %*% (sparse_data * Zi2[, 3]) + alpha3)
    phi3[[j]] <- extraDistr::rdirichlet(nrow(vsum13), vsum13)
  }
  
  
  ##�g�s�b�N�������T���v�����O
  #�g�s�b�N�����̖ޓx��ݒ�
  par1 <- phi1[word_vec]   
  par2 <- rowSums(t(phi2)[word_vec, , drop=FALSE] * Zi12[d_id, ])
  par3 <- matrix(0, nrow=f, ncol=k2)
  for(j in 1:k2){
    par3[, j] <- rowSums(t(phi3[[j]])[word_vec, , drop=FALSE] * Zi1[d_id, index_z1[[j]], drop=FALSE])
  }
  z_par <- theta[d_id, ] * cbind(par1, par2, rowSums(par3))   #���x�����Ƃ̃g�s�b�N�ޓx
  
  #�������z����g�s�b�N�������T���v�����O
  z2_rate <- z_par / rowSums(z_par)   #���x�������m��
  Zi2 <- rmnom(f, 1, z2_rate)   #�������z���烌�x�������𐶐�
  Zi2_T <- t(Zi2)
  
  
  ##�g�s�b�N���z���X�V
  #�f�B���N�����z�̃p�����[�^
  wsum0 <- matrix(0, nrow=d, ncol=L)
  for(i in 1:d){
    wsum0[i, ] <- Zi2_T[, doc_list[[i]]] %*% doc_vec[[i]]
  }
  wsum <- wsum0 + alpha2 
  
  #�f�B���N�����z����p�����[�^���T���v�����O
  theta <- extraDistr::rdirichlet(d, wsum)
  
  
  ##�p�����[�^�̊i�[�ƃT���v�����O���ʂ̕\��
  #�T���v�����O���ꂽ�p�����[�^���i�[
  if(rp%%keep==0){
    #�T���v�����O���ʂ̊i�[
    mkeep <- rp/keep
    THETA[, , mkeep] <- theta
    PHI1[mkeep, ] <- phi1
    PHI2[, , mkeep] <- phi2
    PHI3[, , mkeep] <- do.call(rbind, phi3)
     
    #�g�s�b�N�����̓o�[���C�����Ԃ𒴂�����i�[����
    if(rp%%keep==0 & rp >= burnin){
      SEG1 <- SEG1 + Zi1
      SEG2 <- SEG2 + Zi2
    }
    
    if(rp%%disp==0){
      #�T���v�����O���ʂ��m�F
      print(rp)
      print(sum(log(rowSums(z_par))))
      print(colSums(Zi1))
      print(round(cbind(theta[1:10, ], thetat1[1:10, ]), 3))
      print(round(rbind(phi2[1:nrow(phi2), 1:20], phit2[, 1:20]), 3))
      print(round(rbind(phi1[1:40], phit1[1:40]), 3))
    }
  }
}

matplot(PHI1, type="l", xlab="�T���v�����O��", ylab="�p�����[�^", main="���x��1�̒P�ꕪ�z�̃T���v�����O����")
matplot(t(PHI2[1, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^", main="���x��2�̒P�ꕪ�z�̃T���v�����O����")
matplot(t(PHI2[2, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^", main="���x��2�̒P�ꕪ�z�̃T���v�����O����")
matplot(t(PHI2[3, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^", main="���x��2�̒P�ꕪ�z�̃T���v�����O����")
matplot(t(PHI2[4, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^", main="���x��2�̒P�ꕪ�z�̃T���v�����O����")
matplot(t(PHI3[1, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^", main="���x��2�̒P�ꕪ�z�̃T���v�����O����")