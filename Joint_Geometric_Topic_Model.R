#####Joint Geometric Topic Model####
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
w <- rtpois(hh, rgamma(item, 25, 0.25), a=1, b=Inf)   #�K�␔
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
    cov <- runif(2, 0.005, 0.125) * diag(2)
    cov[1, 2] <- cov[2, 1] <- runif(1, -0.6, 0.6) * prod(sqrt(diag(cov)))
    geo_item0[index, ] <- mvrnorm(length(index), c(runif(1, longitude[1], longitude[2]), runif(1, latitude[1], latitude[2])), cov)
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
  alpha2 <- 2.0
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


####EM�A���S���Y����Joint Geometric Topic Model�𐄒�####
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
loglike <- function(x, v, Data, theta, prob_topic, d_par_matrix, d_id, j){
  #�p�����[�^��ݒ�
  phi_par <- exp(c(0, x))
  
  #�ꏊ�I���m����ݒ�
  denom_par <- (d_par_matrix %*% phi_par)[d_id, ]   #�����ݒ�
  prob_spot <- (phi_par[v] * d_par) / denom_par   #�g�s�b�N���ƂɑI���m��
  
  #���S�f�[�^�̑ΐ��ޓx�̘a
  LL <- sum(prob_topic[, j] * log(theta[d_id, j] * prob_spot))
  return(LL)
}

gradient <- function(x, v, Data, theta, prob_topic, d_par_matrix, d_id, j){
  #�p�����[�^��ݒ�
  phi_par <- exp(c(0, x))
  
  #�ꏊ�I���m����ݒ�
  denom_par <- (d_par_matrix0 * matrix(phi_par, nrow=hh, ncol=item, byrow=T))   #�����ݒ�
  prob_spot <- denom_par[d_id, ] / rowSums(denom_par)[d_id]   #�g�s�b�N���ƂɑI���m��
  
  #���z�x�N�g�����Z�o
  sc <- colSums(prob_topic[, j] * (Data - prob_spot))[-1]
  return(sc)
}

##�C���f�b�N�X�ƃf�[�^��ݒ�
#�C���f�b�N�X�̐ݒ�
v_index <- v_vec <- d_vec <- list()
for(i in 1:hh){
  d_vec[[i]] <- rep(1, length(d_index[[i]]))
}
for(j in 1:item){
  v_index[[j]] <- which(v==j)
  v_vec[[j]] <- rep(1, length(v_index[[j]]))
}

#�f�[�^�̐ݒ�
Data <- as.matrix(sparse_data); storage.mode(Data) <- "integer"
d_par_matrix0 <- matrix(d0, nrow=hh, ncol=item, byrow=T)
  
##�p�����[�^�̐^�l
beta <- betat 
theta <- thetat
phi <- phit

##�p�����[�^�̏����l
beta <- 1.0
theta <- extraDistr::rdirichlet(hh, rep(1.0, k))
phi <- cbind(0, mvrnorm(k, rep(0, item-1), 0.1 * diag(item-1)))

##�ꏊ�̑I���m���̏����l
#�p�����[�^��ݒ�
phi_par <- t(exp(phi))
d_par <- exp(-beta/2 * d)
d_par_matrix <- matrix(exp(-beta/2 * d0), nrow=hh, ncol=item, byrow=T)
denom_par <- (d_par_matrix %*% phi_par)[d_id, ]   #�����ݒ�

#�g�s�b�N���ƂɑI���m�����Z�o
prob_spot <- (phi_par[v, ] * d_par) / denom_par


##�X�V�X�e�[�^�X
LL1 <- -1000000000
dl <- 100   #EM�X�e�b�v�ł̑ΐ��ޓx�̍��̏����l
tol <- 10.0
iter <- 0 

####EM�A���S���Y���Ńp�����[�^�𐄒�####
while(abs(dl) >= tol){ #dl��tol�ȏ�̏ꍇ�͌J��Ԃ�
  
  ##E�X�e�b�v�Ńg�s�b�N�I���m�����Z�o
  Lho <- theta[d_id, ] * prob_spot   #�ޓx�֐�
  prob_topic <- Lho / as.numeric(Lho %*% rep(1, k))   #�g�s�b�N�I���m��
  prob_topic_T <- t(prob_topic)
  

  ##M�X�e�b�v�Ńg�s�b�N���z�̃p�����[�^�𐄒�
  #���[�U�[���ƂɃg�s�b�N������ݒ�
  wsum <- matrix(0, nrow=hh, ncol=k) 
  for(i in 1:hh){
    wsum[i, ] <- prob_topic_T[, d_index[[i]], drop=FALSE] %*% d_vec[[i]]
  }
  #�g�s�b�N���z���X�V
  theta <- wsum / w   
  
  ##���j���[�g���@�ŏꏊ���z�̃p�����[�^�𐄒�
  #�g�s�b�N���ƂɃp�����[�^���X�V
  for(j in 1:k){
    x <- phi[j, -1]
    res <- optim(x, loglike, gr=gradient, v, Data, theta, prob_topic, d_par_matrix, d_id, j, 
                 method="BFGS", hessian=FALSE, control=list(fnscale=-1, trace=FALSE, maxit=1))
    phi[j, -1] <- res$par
  }
  
  #�ꏊ�I���m�����X�V
  phi_par <- t(exp(phi))
  d_par <- exp(-beta/2 * d)
  d_par_matrix <- matrix(exp(-beta/2 * d0), nrow=hh, ncol=item, byrow=T)
  denom_par <- (d_par_matrix %*% phi_par)[d_id, ]   #�����ݒ�
  prob_spot <- (phi_par[v, ] * d_par) / denom_par   #�g�s�b�N���ƂɑI���m�����Z�o
  
  
  ##�ΐ��ޓx���X�V
  LL <- sum(log((theta[d_id, ] * prob_spot) %*% rep(1, k)))   #�ϑ��f�[�^�̑ΐ��ޓx
  iter <- iter + 1
  dl <- LL - LL1
  LL1 <- LL
  print(LL)
  gc()
}

