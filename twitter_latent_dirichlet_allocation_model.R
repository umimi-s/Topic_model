#####Twitter LDA#####
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

####�f�[�^�̔���####
##�����f�[�^�̐ݒ�
hh <- 2000   #���[�U�[��
tweet <- rpois(hh, rgamma(hh, 20.0, 0.2))
d <- sum(tweet)
w <- rpois(d, 12.5)
f <- sum(w)
v1 <- 700   #�g�s�b�N�̌�b��
v2 <- 500   #��ʌ�̌�b��
v <- v1+v2   #����b��
k <- 15   #�g�s�b�N��

#ID�̐ݒ�
u_id <- rep(1:hh, tweet)   
t_id <- as.numeric(unlist(tapply(1:d, u_id, rank)))
index_id <- list()
for(i in 1:hh){
  index_id[[i]] <- which(u_id==i)
}


##�p�����[�^�̐ݒ�
#�f�B�N�������O���z��ݒ�
alpha1 <- rep(0.15, k)   #���[�U�[�ŗL�̃f�B�N�������z�̃p�����[�^
alpha21 <- c(rep(0.04, v1), rep(0.0001, v2))   #�g�s�b�N��̃f�B�N�������z�̃p�����[�^
alpha22 <- c(rep(0.01, v1), rep(5.0, v2))   #��ʌ�̃f�B�N�������z�̎��O���z�̃p�����[�^
beta <- c(4.5, 3.5)   #��ʌꂩ�ǂ����̃x�[�^���z�̃p�����[�^


##���ׂĂ̒P�ꂪ�o������܂Ńf�[�^�̐����𑱂���
rp <- 0
repeat {
  rp <- rp + 1
  
  #�f�B�N�������z����p�����[�^�𐶐�
  thetat <- theta <- extraDistr::rdirichlet(hh, alpha1)   #���[�U�[�g�s�b�N�̐���
  lambda <- lambdat <- rbeta(hh, beta[1], beta[2])   #��ʌ�ƃg�s�b�N��̔䗦
  phi <- extraDistr::rdirichlet(k, alpha21)   #�g�s�b�N��̏o�����̐���
  gamma <- gammat <- extraDistr::rdirichlet(1, alpha22)   #��ʌ�̏o�����̐���
  
  #�P��o���m�����Ⴂ�g�s�b�N�����ւ���
  index <- which(colMaxs(phi) < (k*10)/f & alpha21==max(alpha21))
  for(j in 1:length(index)){
    phi[as.numeric(rmnom(1, 1, extraDistr::rdirichlet(1, alpha1)) %*% 1:k), index[j]] <- (k*10)/f
  }
  phit <- phi
  
  ##�������z����g�s�b�N����ђP��f�[�^�𐶐�
  WX <- matrix(0, nrow=d, ncol=v)
  Z_list <- y_list <- word_list <- list()
  index_word1 <- 1:v1
  index_word2 <- (v1+1):v
  
  #tweet���Ƃ�1�̃g�s�b�N�����蓖�ĒP��𐶐�
  for(i in 1:hh){
    
    #tweet���ƂɃg�s�b�N�𐶐�
    z <- rmnom(tweet[i], 1, theta[i, ])
    z_vec <-as.numeric(z %*% 1:k)
    index_hh <- index_id[[i]]
    
    #tweet�Ɋ��蓖�Ă�ꂽ�g�s�b�N����P��𐶐�
    for(j in 1:nrow(z)){
      
      #�g�s�b�N�Ɋ֌W���邩�ǂ����̐��ݕϐ�
      freq <- w[index_hh[j]]
      y <- rbinom(freq, 1, lambda[i])
      index_y1 <- which(y==1); index_y0 <- which(y==0)
      
      #���ݕϐ��Ɋ�Â���tweet�̒P��𐶐�
      word <- matrix(0, nrow=freq, ncol=v)
      word[index_y1, ] <- rmnom(sum(y), 1, phi[z_vec[j], ])   #�g�s�b�N��̐���
      word[index_y0, ] <- rmnom(sum(1-y), 1, gamma)   #��ʌ�̐���
      
      #���������f�[�^���i�[
      word_list[[index_hh[j]]] <- as.numeric(word %*% 1:v)
      WX[index_hh[j], ] <- colSums(word)
      y_list[[index_hh[j]]] <- y
    }
    #�g�s�b�N���i�[
    Z_list[[i]] <- as.numeric(z_vec)
  }
  #break����
  print(min(colSums(WX)))
  if(min(colSums(WX)) > 0){
    break
  }
}

#���X�g��ϊ�
wd <- unlist(word_list)
y_vec <- unlist(y_list)
z_vec <- unlist(Z_list)
storage.mode(WX) <- "integer"

#�X�p�[�X�f�[�^���쐬
sparse_data <- as(WX, "CsparseMatrix")
word_data <- sparseMatrix(1:f, wd, x=rep(1, f), dims=c(f, v))


####�}���R�t�A�������e�J�����@�őΉ��g�s�b�N���f���𐄒�####
##�A�C�e�����Ƃɖޓx�ƕ��S�����v�Z����֐�
burden_fr <- function(theta, phi, wd, w, k, vec_k){
  #���S�W�����v�Z
  Bur <- theta[w, ] * t(phi)[wd, ]   #�ޓx
  Br <- Bur / as.numeric(Bur %*% vec_k)   #���S��
  r <- colSums(Br) / sum(Br)   #������
  bval <- list(Br=Br, Bur=Bur, r=r)
  return(bval)
}

##�A���S���Y���̐ݒ�
R <- 3000
keep <- 2  
iter <- 0
burnin <- 500
disp <- 10

##�f�[�^�ƃC���f�b�N�X�̐ݒ�
#�f�[�^�̐ݒ�
user_id <- rep(u_id, w)
d_id <- rep(1:d, w)
vec_k <- rep(1, k)

#�C���f�b�N�X�̐ݒ�
user_dt <- sparseMatrix(user_id, 1:f, x=rep(1, f), dims=c(hh, f))
u_dt <- sparseMatrix(u_id, 1:d, x=rep(1, d), dims=c(hh, d))
d_dt <- sparseMatrix(d_id, 1:f, x=rep(1, f), dims=c(d, f))
wd_dt <- t(word_data)
user_n <- rowSums(user_dt)


##���O���z�̐ݒ�
#�n�C�p�[�p�����[�^�̎��O���z
alpha1 <- 0.1
beta1 <- 0.01  
gamma1 <- 0.01 
s0 <- 1
v0 <- 1

##�p�����[�^�̐^�l
theta <- thetat
lambda <- lambdat
phi <- phit 
gamma <- as.numeric(gammat)


##�p�����[�^�̏����l
theta <- extraDistr::rdirichlet(d, rep(2.0, k))
lambda <- rbeta(hh, 2.0, 2.0)
phi <- extraDistr::rdirichlet(k, rep(2.0, v))
gamma <- as.numeric(extraDistr::rdirichlet(1, rep(2.0, v)))


##�p�����[�^�̊i�[�p�z��
THETA <- array(0, dim=c(hh, k, R/keep))
LAMBDA <- matrix(0, nrow=R/keep, ncol=hh)
PHI <- array(0, dim=c(k, v, R/keep))
GAMMA <- matrix(0, nrow=R/keep, ncol=v)
SEG <- matrix(0, nrow=d, ncol=k)
storage.mode(SEG) <- "integer"


##�ΐ��ޓx�̊�l
#���j�O�������f���̑ΐ��ޓx
LLst <- sum(word_data %*% log(colSums(word_data) / f))

#�x�X�g�ȑΐ��ޓx
LL_topic <- sum(log(rowSums(thetat[user_id, ] * t(phit)[wd, ])[y_vec==1]))
LL_general <- sum(log((gammat[wd])[y_vec==0]))
LLbest <- LL_topic + LL_general


####�M�u�X�T���v�����O�Ńp�����[�^���T���v�����O####
for(rp in 1:R){
  
  ##�g�s�b�N�ꂩ��ʌꂩ�ǂ������T���v�����O
  #�g�s�b�N�̖ޓx
  Lho_topic <- theta[user_id, ] * t(phi)[wd, ]
  Lho_general <- gamma[wd]

  #�g�s�b�N�ƈ�ʌ�̊����m��
  r <- lambda[user_id]
  Lho <- cbind(r * as.numeric(Lho_topic %*% vec_k), (1-r) * Lho_general)   #�g�s�b�N�ƈ�ʌ�̊��Җޓx
  allocation_rate <- Lho / rowSums(Lho)
  
  #�񍀕��z���犄�����T���v�����O
  y <- rbinom(f, 1, allocation_rate)
  
  #�x�[�^���z���獬�������T���v�����O
  n <- as.numeric(user_dt %*% y)
  s1 <- n + s0
  v1 <- user_n - n + v0
  lambda <- rbeta(hh, s1, v1)   #�p�����[�^���T���v�����O

  ##�c�C�[�g�P�ʂŃg�s�b�N���T���v�����O
  #�g�s�b�N�̊����m����ݒ�
  Lho <- as.matrix(d_dt %*% (Lho_topic * y))   #��ʌ���������g�s�b�N��̖ޓx
  topic_rate <- Lho / as.numeric(Lho %*% vec_k)
  index_na <- which(is.na(as.numeric(topic_rate %*% vec_k)))
  
  #�������z����g�s�b�N���T���v�����O
  Zi <- matrix(0, nrow=d, ncol=k)
  Zi[-index_na, ] <- rmnom(d-length(index_na), 1, topic_rate[-index_na, ])
  
  
  ##�f�B���N�����z����p�����[�^���T���v�����O
  #�g�s�b�N���z���T���v�����O
  wsum <- as.matrix(u_dt %*% Zi) + alpha1
  theta <- extraDistr::rdirichlet(hh, wsum)
  
  #�g�s�b�N�ꕪ�z���T���v�����O
  vsum <- as.matrix(t(wd_dt %*% (Zi[d_id, ] * y))) + beta1
  phi <- extraDistr::rdirichlet(k, vsum)

  #��ʌꕪ�z���T���v�����O
  gsum <- as.numeric(wd_dt %*% (1-y)) + beta1
  gamma <- as.numeric(extraDistr::rdirichlet(1, gsum))
  

  ##�p�����[�^�̊i�[�ƃT���v�����O���ʂ̕\��
  #�T���v�����O���ꂽ�p�����[�^���i�[
  if(rp%%keep==0){
    mkeep <- rp/keep
    THETA[, , mkeep] <- theta
    LAMBDA[mkeep, ] <- lambda
    PHI[, , mkeep] <- phi
    GAMMA[mkeep, ] <- gamma
    if(burnin > rp){
      SEG <- SEG + Zi
    }
  }
  
  if(rp%%disp==0){
    #�ΐ��ޓx���v�Z
    LL <- sum(log(rowSums(allocation_rate * cbind(as.numeric(Lho_topic %*% vec_k), Lho_general))))
    
    #�T���v�����O���ʂ��m�F
    print(rp)
    print(c(LL, LLbest, LLst))
    print(round(cbind(phi[, 696:705], phit[, 696:705]), 3))
    print(round(rbind(gamma[691:710], gammat[691:710]), 3))
  }
}


####�T���v�����O���ʂ̉����Ɨv��####
burnin <- 2000/keep
RS <- R/keep

##�T���v�����O���ʂ��v���b�g
matplot(t(THETA[1, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA[100, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA[1000, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(PHI[, 1, ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(PHI[, 700, ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(PHI[, 701, ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(GAMMA[, 691:700], type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(GAMMA[, 701:710], type="l", xlab="�T���v�����O��", ylab="�p�����[�^")

##�p�����[�^�̃T���v�����O���ʂ̗v��
round(cbind(apply(THETA[, , burnin:RS], c(1, 2), mean), thetat), 3)   #���[�U�[�̃g�s�b�N�����m��
round(cbind(t(apply(PHI[, , burnin:RS], c(1, 2), mean)), t(phit)), 3)   #�g�s�b�N��̃g�s�b�N�ʂ̏o���m��
round(cbind(colMeans(GAMMA[burnin:RS, ]), as.numeric(gammat)), 3)   #��ʌ�̏o���m��

##�g�s�b�N�̃T���v�����O���ʂ̗v��
round(cbind(SEG/rowSums(SEG), z_vec), 3)   #tweet���Ƃ̃g�s�b�N�����̗v��
