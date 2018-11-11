#####�����g�s�b�N���f��#####
library(MASS)
library(lda)
library(RMeCab)
library(gtools)
library(reshape2)
library(dplyr)
library(plyr)
library(ggplot2)


####�f�[�^�̔���####
#set.seed(423943)
#�f�[�^�̐ݒ�
k <- 5   #�g�s�b�N��
d <- 200   #������
v <- 100   #��b��
w <- 200   #1����������̒P�ꐔ 
m <- 20   #�^�O��
g <- 10   #1����������̃^�O��

#�p�����[�^�̐ݒ�
alpha0 <- runif(k, 0.1, 0.8)   #�����̃f�B���N�����O���z�̃p�����[�^
alpha1 <- rep(0.25, v)   #�P��̃f�B���N�����O���z�̃p�����[�^
alpha2 <- rep(0.15, m)   #�^�O�̃f�B���N�����O���z�̃p�����[�^

#�f�B���N�������̔���
theta0 <- rdirichlet(d, alpha0)   #�����̃g�s�b�N���z���f�B���N���������甭��
phi0 <- rdirichlet(k, alpha1)   #�P��̃g�s�b�N���z���f�B���N���������甭��
gamma0 <- rdirichlet(k, alpha2)

#�������z�̗�������f�[�^�𔭐�
WX <- matrix(0, d, v)
TX <- matrix(0, d, m)
ZS1 <- list()
ZS2 <- list()

for(i in 1:d){
  #�g�s�b�N�𐶐�
  z1 <- t(rmultinom(w, 1, theta0[i, ]))   #�����̒P��̃g�s�b�N�𐶐�
  z2 <- t(rmultinom(g, 1, theta0[i, ]))   #�����̃^�O�̃g�s�b�N�𐶐�
  zn1 <- z1 %*% c(1:k)   #0,1�𐔒l�ɒu��������
  zdn1 <- cbind(zn1, z1)   #apply�֐��Ŏg����悤�ɍs��ɂ��Ă���
  zn2 <- z2 %*% c(1:k)   
  zdn2 <- cbind(zn2, z2)

  #�g�s�b�N���牞���ϐ��𐶐�
  wn <- t(apply(zdn1, 1, function(x) rmultinom(1, 1, phi0[x[1], ])))   #�����̃g�s�b�N����P��𐶐�
  tn <- t(apply(zdn2, 1, function(x) rmultinom(1, 1, gamma0[x[1], ])))   #�����̃g�s�b�N����^�O�𐶐�
  
  wdn <- colSums(wn)   #�P�ꂲ�Ƃɍ��v����1�s�ɂ܂Ƃ߂�
  tdn <- colSums(tn)   #�^�O���Ƃɍ��v����1�s�ɂ܂Ƃ߂� 
  WX[i, ] <- wdn  
  TX[i, ] <- tdn
  ZS1[[i]] <- cbind(rep(i, w), zdn1[, 1])
  ZS2[[i]] <- cbind(rep(i, g), zdn2[, 1])
  print(i)
}


#���X�g���s������ɕύX
ZS1 <- do.call(rbind, ZS1)
ZS2 <- do.call(rbind, ZS2)

#�g�s�b�N�̒P���W�v
z1_table <- table(ZS1[, 2])
z2_table <- table(ZS2[, 2])
z1_r <- z1_table/sum(z1_table)
z2_r <- z2_table/sum(z2_table)

barplot(z1_table, names.arg=c("seg1", "seg2", "seg3", "seg4", "seg5"))
barplot(z2_table, names.arg=c("seg1", "seg2", "seg3", "seg4", "seg5"))

round(colSums(WX)/sum(WX), 3)   #�P��̏o���p�x
round(colSums(TX)/sum(TX), 3)   #�^�O�̏o���p�x


####�}���R�t�A�������e�J�����@�Ō����g�s�b�N���f���𐄒�####
####�}���R�t�A�������e�J�����@�̐ݒ�####
R <- 10000   #�T���v�����O��
keep <- 2   
iter <- 0

#�n�C�p�[�p�����[�^�̎��O���z�̐ݒ�
alpha <- alpha0   #�����̃f�B���N�����O���z�̃p�����[�^
beta <- alpha1[1]   #�P��̃f�B���N�����O���z�̃p�����[�^
gamma <- alpha2[2]   #�^�O�̃f�B���N�����O���z�̃p�����[�^

#�p�����[�^�̏����l
theta.ini <- runif(k, 0.3, 1.5)
phi.ini <- runif(v, 0.5, 1)
psi.ini <- runif(m, 0.5, 1)
theta <- rdirichlet(d, theta.ini)   #�����g�s�b�N�̃p�����[�^�̏����l
phi <- rdirichlet(k, phi.ini)   #�P��g�s�b�N�̃p�����[�^�̏����l
psi <- rdirichlet(k, psi.ini)   #�^�O�g�s�b�N�̃p�����[�^�̏����l

#�p�����[�^�̊i�[�p�z��
THETA <- array(0, dim=c(d, k, R/keep))
PHI <- array(0, dim=c(k, v, R/keep))
PSI <- array(0, dim=c(k, m, R/keep))
W.SEG <- matrix(0, nrow=d*w, R/keep)
T.SEG <- matrix(0, nrow=d*g, R/keep)
RATE1 <- matrix(0, nrow=R/keep, ncol=k)
RATE2 <- matrix(0, nrow=R/keep, ncol=k)


####�f�[�^�̏���####
#ID���쐬
d.id1 <- rep(1:d, rep(v, d))
w.id <- rep(1:v, d) 
d.id2 <- rep(1:d, rep(m, d))
g.id <- rep(1:m, d)
ID1 <- data.frame(d.id=d.id1, w.id=w.id)
ID2 <- data.frame(d.id=d.id2, g.id=g.id)

#�C���f�b�N�X���쐬
index_w <- matrix(1:nrow(ID1), nrow=d, ncol=v, byrow=T)
index_g <- matrix(1:nrow(ID2), nrow=d, ncol=m, byrow=T)

index_g
cbind(X1_Z, as.numeric(t(WX)))
cbind(X2_Z, as.numeric(t(TX)))

##�g�s�b�N�����̏����l�𐶐�
#�g�s�b�N�����̊i�[�p
X1_Z <- matrix(0, nrow=nrow(ID1), ncol=k)
X2_Z <- matrix(0, nrow=nrow(ID2), ncol=k)

#�������ƂɒP�ꂨ��у^�O�̃g�s�b�N�𐶐�
for(i in 1:d){
  
  #theta���s��`���ɕύX
  theta.m1 <- matrix(theta[i, ], nrow=k, ncol=v) 
  theta.m2 <- matrix(theta[i, ], nrow=k, ncol=m)
  
  #���������v�Z
  z1.rate <- t(phi * theta.m1) / matrix(rowSums(t(phi * theta.m1)), nrow=v, ncol=k)
  z2.rate <- t(psi * theta.m2) / matrix(rowSums(t(psi * theta.m2)), nrow=m, ncol=k)
  
  #�P��ƃ^�O�̃g�s�b�N����������
  X1_Z[index_w[i, ], ] <- t(apply(cbind(WX[i, ], z1.rate), 1, function(x) rmultinom(1, x[1], x[-1])))
  X2_Z[index_g[i, ], ] <- t(apply(cbind(TX[i, ], z2.rate), 1, function(x) rmultinom(1, x[1], x[-1])))
}

##�g�s�b�N�������̏����l���v�Z
#�S�̂ł̃g�s�b�N����
k1_sum <- colSums(X1_Z)
k2_sum <- colSums(X2_Z)

#�������Ƃ̃g�s�b�N����
kw_sum <- matrix(0, nrow=d, ncol=k)
kg_sum <- matrix(0, nrow=d, ncol=k)

for(i in 1:d){
  kw_sum[i, ] <- colSums(X1_Z[index_w[i, ], ])
  kg_sum[i, ] <- colSums(X2_Z[index_g[i, ], ])
}

#�P�ꂨ��у^�O���Ƃ̃g�s�b�N����
#�P�ꂲ�Ƃ̊���
kv_sum <- matrix(0, nrow=v, ncol=k)
for(i in 1:v){ kv_sum[i, ] <- colSums(X1_Z[index_w[, i], ])}

#�^�O���Ƃ̊���
km_sum <- matrix(0, nrow=m, ncol=k)
for(i in 1:m){ km_sum[i, ] <- colSums(X2_Z[index_g[, i], ])}

#�g�s�b�N�������x�N�g���`���ɕύX
seg_vec1 <- unlist(apply(X1_Z, 1, function(x) rep(1:k, x)))
seg_vec2 <- unlist(apply(X2_Z, 1, function(x) rep(1:k, x)))

#�s��`���ɕύX
seg_mx1 <- matrix(0, nrow=length(seg_vec1), ncol=k)
seg_mx2 <- matrix(0, nrow=length(seg_vec2), ncol=k)
for(i in 1:nrow(seg_mx1)) {seg_mx1[i, seg_vec1[i]] <- 1}
for(i in 1:nrow(seg_mx2)) {seg_mx2[i, seg_vec2[i]] <- 1}


##�g�s�b�N�����x�N�g����ID���쐬
id_vec11 <- rep(1:d, rep(w, d))
id_vec21 <- rep(1:d, rep(g, d))
id_vec12 <- c()
id_vec22 <- c()

for(i in 1:d){
  id_vec12 <- c(id_vec12, rep(1:v, rowSums(X1_Z[index_w[i, ], ])))
  id_vec22 <- c(id_vec22, rep(1:m, rowSums(X2_Z[index_g[i, ], ])))
}

Z1 <- matrix(0, nrow=d*w, k)
Z2 <- matrix(0, nrow=d*g, k)

#�M�u�X�T���v�����O�p�̃C���f�b�N�X���쐬
index_word <- list()
index_tag <- list()

for(i in 1:d){
  index_word[[i]] <- subset(1:length(id_vec11), id_vec11==i)
  index_tag[[i]] <- subset(1:length(id_vec21), id_vec21==i)
}


####���Ӊ��M�u�X�T���v�����O�Ő���####
for(rp in 1:R){
  
  ##�g�s�b�N���T���v�����O
  for(i in 1:d){
    ##�P��̃g�s�b�N���T���v�����O
    for(wd in 1:length(index_word[[i]])){
      index1 <- index_word[[i]][wd]   #�P��̃C���f�b�N�X
      
      #�g�s�b�N��������P��̃g�s�b�N����菜��
      mx1 <- seg_mx1[index1, ]
      k1 <- k1_sum - mx1
      kw <- kw_sum[i, ] - mx1
      kv <- kv_sum[id_vec12[index1], ] - mx1
      
      #�P��̃g�s�b�N�����m�����v�Z
      z1_sums <- (kw + kg_sum[i, ] + alpha) * (kv + beta) / (k1 + beta*v)
      z1_rate <- z1_sums / sum(z1_sums)
      
      #�g�s�b�N���T���v�����O
      Z1 <- t(rmultinom(1, 1, z1_rate))
      
      #�f�[�^���X�V
      k1_sum <- k1 + Z1
      kw_sum[i, ] <- kw + Z1
      kv_sum[id_vec12[index1], ] <- kv + Z1
      seg_mx1[index1, ] <- Z1
    }
    
    ##�^�O�̃g�s�b�N���T���v�����O
    for(tg in 1:length(index_tag[[i]])){
      index2 <- index_tag[[i]][tg]   #�^�O�̃C���f�b�N�X
      
      #�g�s�b�N��������P��̃g�s�b�N����菜��
      mx2 <- seg_mx2[index2, ]
      k2 <- k2_sum - mx2
      kg <- kg_sum[i, ] - mx2
      km <- km_sum[id_vec22[index2], ] - mx2

      #�^�O�̃g�s�b�N�����m�����v�Z
      z2_sums <- (kg + kw_sum[i, ] + alpha) * (km + gamma) / (k2 + gamma*m)
      z2_rate <- z2_sums / sum(z2_sums)
      
      #�g�s�b�N���T���v�����O
      Z2 <- t(rmultinom(1, 1, z2_sums))
      
      #�f�[�^���X�V
      k2_sum <- k2 + Z2
      kg_sum[i, ] <- kg + Z2
      km_sum[id_vec22[index2], ] <- km + Z2
      seg_mx2[index2, ] <- Z2
    }
  }
  
  ##�T���v�����O���ʂ�ۑ�
  mkeep <- rp/keep
  if(rp%%keep==0){
    
    #�������̌v�Z
    rate11 <- colSums(seg_mx1)/nrow(seg_mx1)
    rate21 <- colSums(seg_mx2)/nrow(seg_mx2)
    
    #�T���v�����O���ʂ�ۑ�
    W.SEG[, mkeep] <- seg_mx1 %*% 1:k 
    T.SEG[, mkeep] <- seg_mx2 %*% 1:k
    RATE1[mkeep, ] <- rate11
    RATE2[mkeep, ] <- rate21
    
    #�T���v�����O�󋵂�\��
    print(rp)
    print(round(rbind(rate11, rate12=z1_r), 3))
    print(round(rbind(rate21, rate22=z2_r), 3))
  }
}

####���茋�ʂƏW�v####
burnin <- 1000   #�o�[���C�����Ԃ�2000��܂�

#�T���v�����O���ʂ̉���
matplot(RATE1, type="l", ylab="������", main="�P��g�s�b�N�̍�����")
matplot(RATE2, type="l", ylab="������", main="�^�O�g�s�b�N�̍�����")

#�������̎��㕽��
round(rbind(rate1_mcmc=colMeans(RATE1[burnin:nrow(RATE1), ]), rate1_true=z1_r), 3)
round(rbind(rate2_mcmc=colMeans(RATE2[burnin:nrow(RATE2), ]), rate2_true=z2_r), 3)

##���肳�ꂽ�g�s�b�N���z
w.seg_freq <- matrix(0, nrow=nrow(W.SEG), ncol=k)
t.seg_freq <- matrix(0, nrow=nrow(T.SEG), ncol=k)

#�P�ꂲ�ƂɃg�s�b�N���z���v�Z
for(i in 1:nrow(W.SEG)){
  print(i)
  w.seg_freq[i, ] <- table(c(W.SEG[i, (burnin+1):(R/keep)], 1:k)) - rep(1, k)
}
w.seg_rate <- w.seg_freq / length((burnin+1):(R/keep))

#�^�O���ƂɃg�s�b�N���z���v�Z
for(i in 1:nrow(T.SEG)){
  print(i)
  t.seg_freq[i, ] <- table(c(T.SEG[i, (burnin+1):(R/keep)], 1:k)) - rep(1, k)
}
t.seg_rate <- t.seg_freq / length((burnin+1):(R/keep))

##�g�s�b�N���z����p�����[�^�𐄒�
theta_w <- matrix(0, nrow=d, ncol=k)
theta_t <- matrix(0, nrow=d, ncol=k)

#�������ƂɃg�s�b�N���z�̃p�����[�^���v�Z
for(i in 1:d){
 theta_w[i, ]  <- colSums(w.seg_rate[id_vec11==i, ])/w
 theta_t[i, ]  <- colSums(t.seg_rate[id_vec21==i, ])/g
}

#�g�s�b�N���z�̃p�����[�^�Ɛ^�̃p�����[�^�̔�r
round(data.frame(word=theta_w, tag=theta_t, topic=theta0), 3)


