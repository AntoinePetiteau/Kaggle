#####TD 1 DU BIG DATA ##############

# libraries
library(readxl)
library(tidyverse)
library(lgarch)		# Gets modelling
library(gets)
library(glmnet) 	# penalized regressions
library(rbridge)	# bridge regressions
library(foreach)
library(doParallel)
library(tseries)
library(tsoutliers)
library(e1071)
library(FactoMineR)
library(cluster)
library(NbClust) 
library(corrplot)

##################### IMPORTATION ET PREMIERS TRAITEMENTS ##################################
setwd("D:/Dossiers/Etudes/M2 EKAP/Big Data/Projet")
base <- read.csv("US.csv", sep=",")

str(base)
dim(base)
View(base)

base$sasdate  <- as.Date(base$sasdate,format = "%m/%d/%Y")
View(base)

#Graphiques pour choisir la var � expliquer
plot(base$INDPRO, type="l", main="Production industrielle") #Production industrielle
plot(base$UNRATE, type="l", main="Taux de chomage") #Taux de chomage
plot(base$CE16OV, type="l", main="Taux d'emploi") #Taux de d'emploi
plot(base$CPIAUCSL, type="l", main = "Inflation") #Inflation
plot(base$HOUST, type="l", main="Construction") #Construction
#On s�lectionne la production industrielle

##Enlever les donn�es d'avant 1970 en raison des NA
base2 <- base [-(1:133),]
#Derni�re ligne contient des na
base2 <- base2[-622,]
#On retire les variables qui ont beaucoup de NA
summary(base2)
base2 <- base2[,!(names(base2) %in% c("UMCSENTx","TWEXAFEGSMTHx","ACOGNO"))]
#On retire les quelques na restants
base2 <- na.omit(base2)
##################################################################################################



############################# OUTLIERS #######################################################
#Analyse des outliers ###
boxplot(base2$INDPRO)
INDPRO<- ts(data=base2$INDPRO, start=c(1970,01), frequency =12)
plot(INDPRO)

tso(INDPRO)
fit <- tso(INDPRO)
plot(fit)
show(fit)

#corriger les outliers
adj<-fit$yadj 

##graphiques des s�ries en niveau de toutes les variables 

plot(adj) #d'apr�s ce graphique on constate que la variable � expliquer 
#a une tendance � la hausse durant la p�riode de l'�tude et elle semble pas stationnaire 
#pour s'assurer on va effectuer le test ADF 

#Etude de la stationnarit� de la variable � expliquer 
library(tseries)
adf.test(base3$INDPRO) #d'apr�s ce test la p value est strictement sup�rieure � 5% 
#H0 est accept�e la s�rie n'est pas stationnaire 

#Etude de la stationnarit� de l'ensemble des variables explicatives 

base2$INDPRO <- adj
####################################################################################################

######################### STATIONNARISER ######################################################
#Boucle pour stationariser
n <- ncol(base2)
base3 = matrix(0,616,125)
base3[,1] <- base2[-1,1]
count = 0
nom_col = names(base2)
for (j in 2:n){
  result_test <- adf.test(base2[,j])
  if (result_test$p.value>0.05){
    base3[,j] <- diff(base2[,j], differences = 1)
    count = count + 1
    cat("Variable stationnaris�e : ",j, "\n")
  }else{
      base3[,j] <- base2[-1,j]
    }
}
cat("Nombre de variables stationnaris�es : ", count, "/", n)

base3 <- as.data.frame(base3)
colnames(base3) <- nom_col

#Export
write.csv(base3, "D:/Dossiers/Etudes/M2 EKAP/Big Data/Projet/base_us.csv")
#######################################################################################################"





####################### STAT DESC ##################################################"
summary(base3$INDPRO)
sd(base3$INDPRO)
#0.11 en moyenne avec un �cart type de 0.46
hist(base3$INDPRO, col = "blue", freq=F, xlab="INDPRO", ylab="Densit�", main="Production industrielle aux USA")
curve(dnorm(x, mean=mean(base3$INDPRO), sd=sd(base3$INDPRO)),col="red", lwd=2, add=TRUE, yaxt="n")
#Distribution proche d'une loi normale, voir les tests 
boxplot(base3$INDPRO, col = "blue", main="Production industrielle aux USA")
#Quelques points extr�mes � la fin de la distribution
#Stat de normalit� :
#skweness - coef d'asym�trie
skewness(base3$INDPRO) 
# -0.7090, l�g�rement n�gatif donc distribution trop d�cal�e � droite de la m�diane
#kurtosis - coef d'applatissement
kurtosis(base3$INDPRO) 
# 2.3951 - La distribution est trop pointue
################################################################################################"




##################### CLASSIFICATION ##################################################"
acp <- PCA(base3[,c(2:125)])
#On oberseve des paquets de variables
barplot(acp$eig[,2], xlab="Dim", ylab ="Percentage of variance", col = 9)
base3cr<-scale(base3[,c(2:125)],center=T,scale=T) #Pour centrer r�duire
pol.dist <- dist(base3cr,method="euc") #Pour calculer la distance
class0 <- hclust(pol.dist, method="ward.D2") #Pour faire les classes
plot(as.dendrogram(class0),main="Dendrogramme") #Pour obtenir le dendogramme avec la m�thode Ward.
plot(class0, hang=-1, cex=0.8, main="Dendrogramme") #M�me graphique, hang=-1 pour mettre les noms sur la m�me ligne. Cex pour la taille du text.

#Classification difficilement interpr�table

#K means
res.kmeans <- kmeans(base3cr, 30, nstart =50, algorithm = "MacQueen") #On utilise la m�thode des kmeans
res.kmeans$cluster #On visulalise les classes
res.kmeans$centers #Les centres de gravit�
res.kmeans$betweenss #Between sum of square. Proportionel � l'inertie inter. C'est ce qu'on veut maximiser. Somme des carr�s expliqu�s
res.kmeans$totss #Total sum of square. 
qual <-res.kmeans$betweenss/res.kmeans$totss
round(qual*100,2) #Qualit� = 53 %
#######################################################################################################"



###################### CORRELATION ######################################################
cor_base3 <- cor(base3[,2:125], method = "spearman")
corrplot(cor_base3, tl.pos="n")

#Recherche des corr�lations les plus importantes :

top_cor <- function(seuil_max, seuil_min,mat_cor){
  compteur = 0
  row_cor <- rownames(mat_cor)
  col_cor <- colnames(mat_cor)
  for (i in 1:(nrow(mat_cor)-1)){
    for (j in (i+1):ncol(mat_cor)){
      if ((mat_cor[i,j]>seuil_max & mat_cor[i,j]< 1) | (mat_cor[i,j]< seuil_min & mat_cor[i,j]>-1)){
        cat("Corr�lation importante : ", row_cor[i], " et ", col_cor[j] , "(cor = ",mat_cor[i,j],")" , "\n")
        compteur = compteur +1
      }
    }
  }
  cat("Nb de corr�lations importantes : ", compteur)
}

top_cor(seuil_max = 0.90,seuil_min=-0.90, mat_cor = cor_base3 )
#######################################################################################
