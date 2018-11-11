#####Multi Hidden Marcov Topic Model#####
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

#set.seed(5723)

####�f�[�^�̔���####
k1 <- 7   #HMM�̍�����
k2 <- 10   #���ʂ̃g�s�b�N��
k3 <- 10   #�����̃g�s�b�N��
d <- 2000   #������
v1 <- 300   #�����W���̌�b��
v2 <- 300   #�������L�̌�b��
v <- v1 + v2
s <- rpois(d, 15)   #���͐�
s[s < 5] <- ceiling(runif(sum(s < 5), 5, 10))
a <- sum(s)   #�����͐�
w <- rpois(a, 12)   #���͂�����̒P�ꐔ
w[w < 5] <- ceiling(runif(sum(w < 5), 5, 10))
f <- sum(w)   #���P�ꐔ

#����ID�̐ݒ�
u_id <- rep(1:d, s)
t_id <- c()
for(i in 1:d){t_id <- c(t_id, 1:s[i])}
words <- as.numeric(tapply(w, u_id, sum))

#���͋�؂�̃x�N�g�����쐬
ID_d <- rep(1:d, words)
td_d <- c()
for(i in 1:d){
  td_d <- c(td_d, rep(1:s[i], w[u_id==i]))
}
nd_d <- rep(1:a, w)
x_vec <- rep(0, f)
x_vec[c(1, cumsum(w[-a])+1)] <- 1

#�C���f�b�N�X��ݒ�
s_list <- list()
for(i in 1:a){
  s_list[[i]] <- which(nd_d==i)
}

##�p�����[�^�̐ݒ�
#�f�B���N�����z�̃p�����[�^
alpha01 <- rep(1, k1)
alpha02 <- matrix(0.3, nrow=k1, ncol=k1)
diag(alpha02) <- 1.5
alpha03 <- rep(0.2, k2)
alpha04 <- rep(0.2, k3)
alpha11 <- c(rep(0.1, v1), rep(0.00025, v2))
alpha12 <- c(rep(0.00025, v1), rep(0.1, v2))

for(l in 1:100){
  print(l)
  #�p�����[�^�𐶐�
  theta1 <- thetat1 <- extraDistr::rdirichlet(1, alpha01)
  theta2 <- thetat2 <- extraDistr::rdirichlet(k1, alpha02)
  theta3 <- thetat3 <- extraDistr::rdirichlet(k1, alpha03) 
  theta4 <- thetat4 <- extraDistr::rdirichlet(d, alpha04)
  gamma <- gammat <- extraDistr::rdirichlet(k2, alpha11)
  phi <- phit <- extraDistr::rdirichlet(k3, alpha12)
  omega <- omegat <- rbeta(d, 25.0, 27.5)
  
  ##���f���ɂ��ƂÂ��P��𐶐�����
  wd_list <- list()
  WX <- matrix(0, nrow=d, ncol=v)
  ID_list <- list()
  td_list <- list()
  Z1_list <- list()
  Z2_list <- list()
  Z3_list <- list()
  Z4_list <- list()
  
  #�P�ꂲ�Ƃɕ��͋��ʂ����͌ŗL���𐶐�
  z1_vec <- rbinom(f, 1, omega[ID_d])
  
  #���͂��Ƃ̃Z�O�����g�𐶐�
  z2_vec2 <- z2_vec <- as.numeric(rmnom(a, 1, theta1) %*% 1:k1)
  freq <- c()
  
  for(i in 1:a){
    flag <- sum(1-z1_vec[s_list[[i]]])
    freq <- c(freq, flag)
    if(t_id[i]==1){
      if(flag==0){
       z2_vec[i] <- 0 
       next
      } 
      if(flag > 0){
        next
      }
    }
    if(t_id[i]!=0){
      if(z2_vec[i-1]==0 & flag==0){
        z2_vec[i] <- 0
        next
      }
      if(z2_vec[i-1]==0 & flag > 0){
        next
      }
      if(z2_vec[i-1]!=0 & flag > 0){
        z2 <- rmnom(1, 1, theta2[z2_vec[i-1], ])
        z2_vec[i] <- as.numeric(z2 %*% 1:k1)
        next
      }
      if(z2_vec[i-1]!=0 & flag==0){
        z2_vec[i] <- z2_vec[i-1]
      }
    }
  }
  Z1 <- z1_vec
  Z2 <- z2_vec
  
  #���͂��Ƃɒ����I�Ƀg�s�b�N�ƒP��𐶐�
  Z3_list <- list()
  Z4_list <- list()
  wd_list <- list()
  WX <- matrix(0, nrow=a, ncol=v)
  
  for(i in 1:a){
    if(i%%1000==0){
      print(i)
    }
    #�p�����[�^�̊i�[�p�z��
    index_id <- u_id[i]
    n <- w[i]
    z3_vec <- rep(0, n)
    z4_vec <- rep(0, n)
    wd <- rep(0, n)
    
    #�������ʂ������ŗL���̎w���ϐ������o��
    flag <- z1_vec[s_list[[i]]]
    index1 <- which(flag==0)
    index2 <- which(flag==1)
    
    #���͋��ʂ̃g�s�b�N�𐶐�
    if(length(index1) > 0){
      z3 <- rmnom(length(index1), 1, theta3[z2_vec[i], ]) 
      z3_vec[index1] <- as.numeric(z3 %*% 1:k2)
    }
  
    #�����ŗL�̃g�s�b�N�̐���
    if(length(index2) > 0){
      z4 <- rmnom(length(index2), 1, theta4[index_id, ]) 
      z4_vec[index2] <- as.numeric(z4 %*% 1:k3)
    }
    
    #���͋��ʂ̃g�s�b�N����P��𐶐�
    index_topic1 <- z3_vec[z3_vec!=0]
    if(length(index_topic1) > 0){
      wd1 <- rmnom(length(index_topic1), 1, gamma[index_topic1, ])
      wd[index1] <- as.numeric(wd1 %*% 1:v)
    }
    
    #�����ŗL�̃g�s�b�N����P��𐶐�
    index_topic2 <- z4_vec[z4_vec!=0]
    if(length(index_topic2) > 0){
      wd2 <- rmnom(length(index_topic2), 1, phi[index_topic2, ]) 
      wd[index2] <- as.numeric(wd2 %*% 1:v)
    }
    
    #�p�����[�^���i�[
    wd_list[[i]] <- wd 
    WX[i, ] <- colSums(wd1) + colSums(wd2)
    Z3_list[[i]] <- z3_vec
    Z4_list[[i]] <- z4_vec
  }
  
  #���X�g���x�N�g���ϊ�
  Z3 <- unlist(Z3_list)
  Z4 <- unlist(Z4_list[[i]])
  wd <- unlist(wd_list)
  if(length(unique(wd))==v){
    break
  }
}
Data <- matrix(as.numeric(table(1:f, wd)), nrow=f, ncol=v)
sparse_data <- as(Data, "CsparseMatrix")
rm(Data)

##�C���f�b�N�X���쐬
doc_list <- list()
td_list <- s_list
word_list <- list()
for(i in 1:d){doc_list[[i]] <- which(ID_d==i)}
for(i in 1:v){word_list[[i]] <- which(wd==i)}


####�}���R�t�A�������e�J�����@��MHMM�g�s�b�N���f���𐄒�####
##�P�ꂲ�Ƃɖޓx�ƕ��S�����v�Z����֐�
burden_fr <- function(theta, phi, wd, w, k){
  Bur <-  matrix(0, nrow=length(wd), ncol=k)   #���S�W���̊i�[�p
  for(j in 1:k){
    #���S�W�����v�Z
    Bi <- rep(theta[, j], w) * phi[j, wd]   #�ޓx
    Bur[, j] <- Bi   
  }
  Br <- Bur / rowSums(Bur)   #���S���̌v�Z
  bval <- list(Br=Br, Bur=Bur)
  return(bval)
}

##�ϑ��f�[�^�̑ΐ��ޓx�Ɛ��ݕϐ�z���v�Z���邽�߂̊֐�
LLobz <- function(Data, phi, r, const, hh, k){
  
  #�������z�̑ΐ��ޓx
  log_phi <- log(t(phi))
  LLi <- const + Data %*% log_phi
  
  #logsumexp�̖ޓx
  LLi_max <- matrix(apply(LLi, 1, max), nrow=hh, ncol=k)
  r_matrix <- matrix(r, nrow=hh, ncol=k, byrow=T)
  
  #�����m���̃p�����[�^��ݒ�
  expl <- r_matrix * exp(LLi - LLi_max)
  expl_log <- log(expl)
  expl_max <- matrix(log(max(expl[1, ])), nrow=hh, ncol=k)
  z <- exp(expl_log - (log(rowSums(exp(expl_log - expl_max))) + expl_max))   #�Z�O�����g�����m��
  
  #�ϑ��f�[�^�̑ΐ��ޓx
  r_log <- matrix(log(r), nrow=hh, ncol=k, byrow=T)
  LLosum <- sum(log(rowSums(exp(r_log + LLi))))   #�ϑ��f�[�^�̑ΐ��ޓx
  rval <- list(LLob=LLosum, z=z, LL=LLi)
  return(rval)
}


####MHMM�g�s�b�N���f����MCMC�A���S���Y���̐ݒ�####
##�A���S���Y���̐ݒ�
R <- 10000
keep <- 2  
iter <- 0
burnin <- 1000/keep
disp <- 10

##�p�����[�^�̐^�l
theta1 <- thetat1
theta2 <- thetat2
theta3 <- thetat3
theta4 <- thetat4
gamma <- gammat
phi <- phit
omega <- omegat
r <- mean(omegat)
z2_vec <- Z2


##MHMT���f���̏����l��ݒ�
##�����������z�ŃZ�O�����g������������
const <- lfactorial(w) - rowSums(lfactorial(WX))   #�������z�̖��x�֐��̑ΐ��ޓx�̒萔

#�p�����[�^�̏����l
#phi�̏����l
alpha0 <- colSums(WX) / sum(WX) + 0.001
phi <- extraDistr::rdirichlet(k1, alpha0*v)

#�������̏����l
r <- rep(1/k1, k1)

#�ϑ��f�[�^�̑ΐ��ޓx�̏�����
L <- LLobz(WX, phi, r, const, a, k1)
LL1 <- L$LLob
z <- L$z

#�X�V�X�e�[�^�X
dl <- 100   #EM�X�e�b�v�ł̑ΐ��ޓx�̍��̏����l
tol <- 1
iter <- 0 

##EM�A���S���Y���őΐ��ޓx���ő剻
while(abs(dl) >= tol){   #dl��tol�ȏ�̏ꍇ�͌J��Ԃ�
  #E�X�e�b�v�̌v�Z
  z <- L$z   #���ݕϐ�z�̏o��
  
  #M�X�e�b�v�̌v�Z�ƍœK��
  #phi�̐���
  df0 <- matrix(0, nrow=k1, ncol=v)
  for(j in 1:k1){
    #���S�f�[�^�̑ΐ��ޓx����phi�̐���ʂ��v�Z
    phi[j, ] <- colSums(matrix(z[, j], nrow=a, ncol=v) * WX) / sum(z[, j] * w)   #�d�ݕt���������z�̍Ŗސ���
  }
  
  #�������𐄒�
  r <- apply(z, 2, sum) / a
  
  #�ϑ��f�[�^�̑ΐ��ޓx���v�Z
  phi[phi==0] <- min(phi[phi > 0])
  L <- LLobz(WX, phi, r, const, a, k1)
  LL <- L$LLob   #�ϑ��f�[�^�̑ΐ��ޓx
  iter <- iter+1   
  dl <- LL-LL1
  LL1 <- LL
  print(LL)
}

#�����l��ݒ�
theta1 <- extraDistr::rdirichlet(1, rep(1, k1))
alpha <- matrix(0.3, nrow=k1, ncol=k1)
diag(alpha) <- 1.5
theta2 <- extraDistr::rdirichlet(k1, alpha)
theta3 <- extraDistr::rdirichlet(k1, rep(0.4, k2))
theta4 <- extraDistr::rdirichlet(d, rep(0.4, k3))
r <- 0.5
gamma <- extraDistr::rdirichlet(k2, c(rep(0.3, v1), rep(0.05, v2)))
phi <- extraDistr::rdirichlet(k3, c(rep(0.05, v1), rep(0.3, v2)))
z2_vec <- as.numeric(rmnom(a, 1, z) %*% 1:k1)


##���O���z�̐ݒ�
#�n�C�p�[�p�����[�^�̎��O���z
alpha01 <- 0.01
alpha02 <- 0.01
alpha03 <- 0.01
beta01 <- 1
beta02 <- 1
beta03 <- 1
beta04 <- 1


##�p�����[�^�̊i�[�p�z��
THETA1 <- matrix(0, nrow=R/keep, ncol=k1)
THETA2 <- array(0, dim=c(k1, k1, R/keep))
THETA3 <- array(0, dim=c(k1, k2, R/keep))
THETA4 <- array(0, dim=c(d, k3, R/keep))
GAMMA <- array(0, dim=c(k2, v, R/keep))
PHI <- array(0, dim=c(k3, v, R/keep))
OMEGA <- rep(0, R/keep)
SEG1 <- rep(0, f)
SEG2 <- matrix(0, nrow=a, ncol=k1)
SEG3 <- matrix(0, nrow=f, ncol=k2)
SEG4 <- matrix(0, nrow=f, ncol=k3)
storage.mode(SEG1) <- "integer"
storage.mode(SEG2) <- "integer"
storage.mode(SEG3) <- "integer"
storage.mode(SEG4) <- "integer"


##MCMC����p�z��
max_time <- max(t_id)
max_word <- max(words)
index_t11 <- which(t_id==1)
index_t21 <- list()
index_t22 <- list()
for(j in 2:max_time){
  index_t21[[j]] <- which(t_id==j)-1
  index_t22[[j]] <- which(t_id==j)
}

#��ΐ��ޓx��ݒ�
LLst <- sum(sparse_data %*% log(colSums(WX)/sum(WX)))


####�M�u�X�T���v�����O��HTM���f���̃p�����[�^���T���v�����O####
for(rp in 1:R){
  
  ##�P�ꂲ�Ƃɕ������ʂ������ŗL���𐶐�
  #�P�ꂲ�Ƃɕ������ʂ̃g�s�b�N�ޓx���v�Z
  z2_indicate <- z2_vec[nd_d]
  index_zeros <- which(z2_indicate==0)
  word_par1 <- matrix(0, nrow=f, ncol=k2)
  if(length(index_zeros) > 0){
    for(j in 1:k2){
      word_par1[-index_zeros, j] <- theta3[z2_indicate[-index_zeros], j] * gamma[j, wd[-index_zeros]]
    }
  } else {
    for(j in 1:k2){
      word_par1[, j] <- theta3[z2_indicate, j] * gamma[j, wd]
    }
  }
  Li1 <- (1-r) * rowSums(word_par1)
  
  #�P�ꂲ�Ƃɕ����ŗL�̃g�s�b�N�ޓx���v�Z
  word_par2 <- burden_fr(theta4, phi, wd, words, k3)
  Li2 <- r * rowSums(word_par2$Bur)

  #���݊m���̌v�Z�Ɛ��ݕϐ��̐���
  z_rate1 <- Li2 / (Li1+Li2)
  Zi1 <- rbinom(f, 1, z_rate1)
  index_z1 <- which(Zi1==1)
  
  #�x�[�^���z���獬�����̍X�V
  r <- rbeta(1, sum(Zi1)+beta01, sum(1-Zi1)+beta01)

  
  ##�������z����P��g�s�b�N�𐶐�
  #�������ʂ̃g�s�b�N�𐶐�
  Zi3 <- matrix(0, nrow=f, ncol=k2)
  z_rate3 <- word_par1 / rowSums(word_par1)
  Zi3[-index_z1, ] <- rmnom(f-length(index_z1), 1, z_rate3[-index_z1, ])
  
  #�����ŗL�̃g�s�b�N�𐶐�
  Zi4 <- matrix(0, nrow=f, ncol=k3)
  z_rate4 <- word_par2$Br
  Zi4[index_z1, ] <- rmnom(length(index_z1), 1, z_rate4[index_z1, ])
  
  
  ##HMM�ŕ��͒P�ʂ̃Z�O�����g�𐶐�
  #���͒P�ʂł̃g�s�b�N�p�x�s����쐬
  HMM_data <- matrix(0, nrow=a, ncol=k2)
  for(i in 1:a){
    HMM_data[i, ] <- rep(1, length(s_list[[i]])) %*% Zi3[s_list[[i]], , drop=FALSE]
  }
  
  #���ݕϐ����Ƃɖޓx�𐄒�
  theta_log <- log(t(theta3))
  LLi0 <- HMM_data %*% theta_log   #�ΐ��ޓx
  LLi_max <- apply(LLi0, 1, max)
  LLi <- exp(LLi0 - LLi_max)   #�ޓx
  
  #�Z�O�����g�����m���̐���ƃZ�O�����g�̐���
  z_rate2 <- matrix(0, nrow=a, ncol=k1)
  Zi2 <- matrix(0, nrow=a, ncol=k1)
  z2_vec <- rep(0, a)
  rf02 <- matrix(0, nrow=k1, ncol=k1) 
  
  for(j in 1:max_time){
    if(j==1){
      #�Z�O�����g�̊����m��
      LLs <- matrix(theta1, nrow=length(index_t11), ncol=k1, byrow=T) * LLi[index_t11, ]   #�d�ݕt���ޓx
      z_rate2[index_t11, ] <- LLs / rowSums(LLs)   #�����m��
      
      #�������z���Z�O�����g�𐶐�
      Zi2[index_t11, ] <- rmnom(length(index_t11), 1, z_rate2[index_t11, ])
      z2_vec[index_t11] <- as.numeric(Zi2[index_t11, ] %*% 1:k1)
      
      #�������̃p�����[�^���X�V
      rf01 <- colSums(Zi2[index_t11, ])
      
    } else {
      
      #�Z�O�����g�̊����m��
      index <- index_t22[[j]]
      LLs <- theta2[z2_vec[index_t21[[j]]], , drop=FALSE] * LLi[index, , drop=FALSE]   #�d�ݕt���ޓx
      z_rate2[index, ] <- LLs / rowSums(LLs)   #�����m��
      
      #�������z���Z�O�����g�𐶐�
      Zi2[index, ] <- rmnom(length(index), 1, z_rate2[index, ])
      z2_vec[index] <- as.numeric(Zi2[index, ] %*% 1:k1)
      
      #�������̃p�����[�^���X�V
      rf02 <- rf02 + t(Zi2[index_t21[[j]], , drop=FALSE]) %*% Zi2[index, , drop=FALSE]   #�}���R�t����
    }
  }

  ##�p�����[�^���T���v�����O
  #�f�B�N�������z����HMM�̍��������T���v�����O
  rf11 <- colSums(Zi2[index_t11, ]) + beta01
  rf12 <- rf02 + alpha01
  theta1 <- extraDistr::rdirichlet(1, rf11)
  theta2 <- extraDistr::rdirichlet(k1, rf12)
  
  #�������ʂ̃g�s�b�N���z�̃p�����[�^���T���v�����O
  wf0 <- matrix(0, nrow=k1, ncol=k2)
  for(j in 1:k1){
    wf0[j, ] <- colSums(Zi2[nd_d, j] * Zi3)
  }
  wf <- wf0 + beta01
  theta3 <- extraDistr::rdirichlet(k1, wf)
  
  
  #�����ŗL�̃g�s�b�N���z�̃p�����[�^���T���v�����O
  wsum0 <- matrix(0, nrow=d, ncol=k3)
  for(i in 1:d){
    wsum0[i, ] <- rep(1, length(doc_list[[i]])) %*% Zi4[doc_list[[i]], ]
  }
  wsum <- wsum0 + beta01
  theta4 <- extraDistr::rdirichlet(d, wsum)
  
  #�P�ꕪ�zgamma���T���v�����O
  gf0 <- matrix(0, nrow=k2, ncol=v)
  for(j in 1:v){
    gf0[, j] <- colSums(Zi3[word_list[[j]], , drop=FALSE])
  }
  gf <- gf0 + alpha02
  gamma <- extraDistr::rdirichlet(k2, gf)
  
  #�P�ꕪ�zphi���T���v�����O
  vf0 <- matrix(0, nrow=k2, ncol=v)
  for(j in 1:v){
    vf0[, j] <- colSums(Zi4[word_list[[j]], , drop=FALSE])
  }
  vf <- vf0 + alpha03
  phi <- extraDistr::rdirichlet(k3, vf)

  
  ##�p�����[�^�̊i�[�ƃT���v�����O���ʂ̕\��
  #�T���v�����O���ꂽ�p�����[�^���i�[
  if(rp%%keep==0){
    #�T���v�����O���ʂ̊i�[
    mkeep <- rp/keep
    THETA1[mkeep, ] <- theta1
    THETA2[, , mkeep] <- theta2
    THETA3[, , mkeep] <- theta3
    THETA4[, , mkeep] <- theta4
    GAMMA[, , mkeep] <- gamma
    PHI[, , mkeep] <- phi
    #OMEGA[mkeep] <- r
    
    #�g�s�b�N�����̓o�[���C�����Ԃ𒴂�����i�[����
    if(mkeep >= burnin & rp%%keep==0){
      SEG1 <- SEG1 + Zi1
      SEG2 <- SEG2 + Zi2
      SEG3 <- SEG3 + Zi3
      SEG4 <- SEG4 + Zi4
    }
    
    #�T���v�����O���ʂ��m�F
    if(rp%%disp==0){
      gamma[gamma==0] <- min(gamma[gamma!=0])
      phi[phi==0] <- min(phi[phi!=0])
      LL <- sum(sparse_data %*% t(log(gamma)) * (1-Zi1) * Zi3) + sum(sparse_data %*% t(log(phi)) * Zi1 * Zi4)
      print(rp)
      print(c(LL, LLst))
      print(round(c(mean(r), mean(omegat)), 3))
      print(round(cbind(theta2, thetat2), 3))
      print(round(cbind(theta3, thetat3), 3))
      print(round(cbind(phi[, 296:305], phit[, 296:305]), 3))
    }
  }
}


####�T���v�����O���ʂ̉����Ɨv��####
burnin <- 1000/keep   #�o�[���C������
RS <- R/keep

##�T���v�����O���ʂ̉���
#�����̃g�s�b�N���z�̃T���v�����O����
matplot(THETA1, type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA2[1, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA2[3, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA2[5, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA2[7, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA3[1, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA3[3, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA3[5, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA3[7, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA4[1, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA4[100, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA4[1000, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA4[2000, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")

#�P��̏o���m���̃T���v�����O����
matplot(t(PHI[, 1, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N1�̒P��̏o�����̃T���v�����O����")
matplot(t(PHI[, 200, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N2�̒P��̏o�����̃T���v�����O����")
matplot(t(PHI[, 400, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N3�̒P��̏o�����̃T���v�����O����")
matplot(t(PHI[, 500, ]), type="l", ylab="�p�����[�^", main="�g�s�b�N4�̒P��̏o�����̃T���v�����O����")


##�T���v�����O���ʂ̗v�񐄒��
#�g�s�b�N���z�̎��㐄���
topic_mu <- apply(THETA[, , burnin:(R/keep)], c(1, 2), mean)   #�g�s�b�N���z�̎��㕽��
round(cbind(topic_mu, thetat), 3)
round(topic_sd <- apply(THETA[, , burnin:(R/keep)], c(1, 2), sd), 3)   #�g�s�b�N���z�̎���W���΍�

#�P��o���m���̎��㐄���
word_mu <- apply(PHI[, , burnin:(R/keep)], c(1, 2), mean)   #�P��̏o�����̎��㕽��
word <- round(t(rbind(word_mu, phit)), 3)
colnames(word) <- 1:ncol(word)
word

##�g�s�b�N�̎��㕪�z�̗v��
round(cbind(z1, seg1_mu <- SEG1 / length(burnin:RS)), 3)
round(cbind(z2, seg2_mu <- SEG2 / rowSums(SEG2)), 3)




