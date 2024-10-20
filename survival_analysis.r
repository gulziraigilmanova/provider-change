install.packages("kmi")
install.packages("mvna")
install.packages("etm")
install.packages("survival")
library(kmi)
library(mvna)
library(etm)
library(survival)

#EVENT: INPATIENT STAY
file_path <- "./output/survival_stationaer_complete.csv"
data_surv_days <- read.csv(file_path)

#sex recode W-1;M-0
data_surv_days$sex <- ifelse(data_surv_days$sex == "W", 1, 0)
# Replace 99 with "cens" in the 'to' column
data_surv_days$to[data_surv_days$to == 99] <- "cens"
head(data_surv_days)
# table of possible transitions
table(data_surv_days$from,data_surv_days$to)
View(data_surv_days)

tra.bws <- matrix(FALSE, 3, 3, dimnames = list(c(0, 1, 2), c(0, 1, 2)))
tra.bws[1, 2:3] <- TRUE
tra.bws[2, 3] <- TRUE
tra.bws
#NEW TRANSITIONS
tra.bws <- matrix(FALSE,3,3)
tra.bws [1,2:3] <- TRUE
tra.bws [2,c(1,3)] <- TRUE
tra.bws <- matrix(FALSE,3,3)
tra.bws [1,2:3] <- TRUE
tra.bws [2,3] <- TRUE

# Cox proportional hazards model with an event as INPATIENT  STAY
#initial to provider change 01
cox.01 <- coxph(Surv(entry, exit, to == 1) ~ as.factor(severe) + as.factor(comorbidity)+ I(age/10) +
                  as.factor(sex), data_surv_days, subset = from == 0)
summary(cox.01)
cox.zph(cox.01)

#initial to inpatient stay 02
cox.02 <- coxph(Surv(entry, exit, to == 2) ~ as.factor(severe) + as.factor(comorbidity)+ I(age/10) +
                  as.factor(sex), data_surv_days, subset = from == 0)
summary(cox.02)
cox.zph(cox.02)

#from provider change to inpatient stay 12
cox.12 <- coxph(Surv(entry, exit, to == 2) ~  as.factor(severe) + as.factor(comorbidity) +I(age/10) +
                  as.factor(sex), data_surv_days, subset = from == 1)

summary(cox.12)
cox.zph(cox.12)

# testing the Markov assumption
coxph(Surv(entry,exit,to =="2")~ entry,data = subset(data_surv_days,from =="1"))

#time-dep covariates
cox <- coxph(Surv(entry, exit, to == 2) ~ as.factor(from) + as.factor(severe) +
               as.factor(comorbidity) + I(age/10) +
               as.factor(sex), data_surv_days)
summary(cox)

#time-dep covariates severity as no factor.
cox <- coxph(Surv(entry, exit, to == 2) ~ as.factor(from)  +
               as.factor(comorbidity)+ I(age/10) +
               as.factor(sex), subset(data_surv_days,severe==1))

summary(cox)$conf.int

#EVENT:DAYPATIENT CARE
file_path <- "./output/survival_teilstationaer_complete.csv"
data_surv_teils <- read.csv(file_path)

#sex recode W-1;M-0
data_surv_teils$sex <- ifelse(data_surv_teils$sex == "W", 1, 0)
# Replace 99 with "cens" in the 'to' column
data_surv_teils$to[data_surv_teils$to == 99] <- "cens"
head(data_surv_teils)
# table of possible transitions
table(data_surv_teils$from,data_surv_teils$to)

tra.bws0 <- matrix(FALSE, 3, 3, dimnames = list(c(0, 1, 2), c(0, 1, 2)))
tra.bws0 [1, 2:3] <- TRUE
tra.bws0 [2, 3] <- TRUE
tra.bws0

#NEW TRANSITIONS
tra.bws0 <- matrix(FALSE,3,3)
tra.bws0 [1,2:3] <- TRUE
tra.bws0 [2,c(1,3)] <- TRUE
tra.bws0 <- matrix(FALSE,3,3)
tra.bws0 [1,2:3] <- TRUE
tra.bws0 [2,3] <- TRUE

# Cox proportional hazards model
#initial to provider change 01
cox.01 <- coxph(Surv(entry, exit, to == 1) ~ as.factor(severe) +
                  as.factor(comorbidity)+ I(age/10) +
                  as.factor(sex), data_surv_teils, subset = from == 0)
summary(cox.01)
cox.zph(cox.01)

#initial to daypatient care 02
cox.02 <- coxph(Surv(entry, exit, to == 2) ~ as.factor(severe)
                + as.factor(comorbidity)+ I(age/10) +
                  as.factor(sex), data_surv_teils, subset = from == 0)
summary(cox.02)
cox.zph(cox.02)

#from provider change to daypatient care 12
cox.12 <- coxph(Surv(entry, exit, to == 2) ~  as.factor(severe) +
                  as.factor(comorbidity) +I(age/10) +
                  as.factor(sex), data_surv_teils, subset = from == 1)

summary(cox.12)
cox.zph(cox.12)

# testing the Markov assumption
coxph(Surv(entry,exit,to =="2")~ entry,data = subset(data_surv_teils,from =="1"))

#time-dep covariates
cox <- coxph(Surv(entry, exit, to == 2) ~ as.factor(from) + as.factor(severe)
              + as.factor(comorbidity)+ I(age/10)+
               as.factor(sex), data_surv_teils)

summary(cox)

#time-dep covariates severity as no factor.
cox <- coxph(Surv(entry, exit, to == 2) ~ as.factor(from)  +
               as.factor(comorbidity)+ I(age/10) +
               as.factor(sex), subset(data_surv_teils,severe==1))

summary(cox)

#FIGURE 3
#fulldata event: Inpatient stay
#nelson-aalen estimator of cumulative incidences

par(mfrow = c(2, 2))
mvna.bws <- mvna(data_surv_days, c("0", "1", "2"), tra.bws, "cens" )
summary(mvna.bws)
line_colors <- c("darkgrey", "darkgreen","darkred")
par(family = "sans")
plot(mvna.bws, col = line_colors, main = "Event: Inpatient Stay",
     xlab = "Days", lty = 1, lwd = 2, cex = 1.2, legend = F)
legend("topleft", inset = c(0.05, 0.05), legend = c("0 1", "0 2", "1 2"),
       col = line_colors, lty = 1, lwd = 2, cex = 1.2, bty = "o")

# aalen-johansen estimator of transition probablities
etm.bws<- etm(data_surv_days, c("0", "1", "2"), tra.bws,
              "cens", s = 0, covariance = F)
summary(etm.bws)
line_colors <- c( "darkgrey", "darkgreen","darkred")
plot(etm.bws, tr.choice = c("0 1", "0 2", "1 2"), col = line_colors,
     xlab = "Days", lty = 1, cex = 1.2, lwd = 2, font.lab = 2, legend = F)
legend("topleft", inset = c(0.05, 0.05), legend = c("0 1", "0 2", "1 2"),
       col = line_colors, lty = 1, lwd = 2, cex = 1.2, bty = "o")

##fulldata, event : daypatient care
mvna.bws0 <- mvna(data_surv_teils, c("0", "1", "2"), tra.bws0, "cens")
summary(mvna.bws0)
line_colors <- c("darkgrey", "darkgreen","darkred")
plot(mvna.bws0, col = line_colors, main = "Event: Daypatient Care", xlab = "Days", lty = 1, lwd = 2,
     font.lab = 2, cex = 1.2, legend= F)
legend("topleft", inset = c(0.05, 0.05), legend = c("0 1", "0 2", "1 2"),
       col = line_colors, lty = 1, lwd = 2, cex = 1.2, bty = "o")

# aalen-johansen estimator of transition probablities
etm.bws0<- etm(data_surv_teils, c("0", "1", "2"), tra.bws0,
               "cens", s = 0, covariance = F)
summary(etm.bws0)
line_colors <- c( "darkgrey", "darkgreen","darkred")
plot(etm.bws0, tr.choice = c("0 1", "0 2", "1 2"), col = line_colors,
     xlab = "Days", lty = 1, cex = 1.2, lwd = 2, font.lab = 2)
legend("topleft", inset = c(0.05, 0.05), legend = c("0 1", "0 2", "1 2"),
       col = line_colors, lty = 1, lwd = 2, cex = 1.2, bty = "o")

##only SMI with Inpatient Stay
file_path <- "./output/survival_stationaer_severe.csv"
data_surv_days_sev <- read.csv(file_path)
#sex recode W-1;M-0
data_surv_days_sev$sex <- ifelse(data_surv_days_sev$sex == "W", 1, 0)
# Replace 99 with "cens" in the 'to' column
data_surv_days_sev$to[data_surv_days_sev$to == 99] <- "cens"
head(data_surv_days_sev)
# table of possible transitions
table(data_surv_days_sev$from,data_surv_days_sev$to)

tra.bws1 <- matrix(FALSE, 3, 3, dimnames = list(c(0, 1, 2), c(0, 1, 2)))
tra.bws1[1, 2:3] <- TRUE
tra.bws1[2, 3] <- TRUE
tra.bws1

#NEW TRANSITIONS

tra.bws1 <- matrix(FALSE,3,3)
tra.bws1 [1,2:3] <- TRUE
tra.bws1 [2,c(1,3)] <- TRUE
tra.bws1 <- matrix(FALSE,3,3)
tra.bws1 [1,2:3] <- TRUE
tra.bws1 [2,3] <- TRUE

##only SMI with daypatient care
file_path <- "./output/survival_teilstationaer_severe.csv"
teil_sev <- read.csv(file_path)
#sex recode W-1;M-0
teil_sev$sex <- ifelse(teil_sev$sex == "W", 1, 0)
# Replace 99 with "cens" in the 'to' column
teil_sev$to[teil_sev$to == 99] <- "cens"
head(teil_sev)

# table of possible transitions
table(teil_sev$from,teil_sev$to)
tra.bws11 <- matrix(FALSE, 3, 3, dimnames = list(c(0, 1, 2), c(0, 1, 2)))
tra.bws11[1, 2:3] <- TRUE
tra.bws11[2, 3] <- TRUE
tra.bws11

#NEW TRANSITIONS
tra.bws11 <- matrix(FALSE,3,3)
tra.bws11 [1,2:3] <- TRUE
tra.bws11 [2,c(1,3)] <- TRUE
tra.bws11 <- matrix(FALSE,3,3)
tra.bws11 [1,2:3] <- TRUE
tra.bws11 [2,3] <- TRUE

##non-SMI with Inpatient Stay
file_path <- "./output/survival_stationaer_non_severe.csv"
data_surv_days_ns <- read.csv(file_path)

#sex recode W-1;M-0
data_surv_days_ns$sex <- ifelse(data_surv_days_ns$sex == "W", 1, 0)
# Replace 99 with "cens" in the 'to' column
data_surv_days_ns$to[data_surv_days_ns$to == 99] <- "cens"

# table of possible transitions
table(data_surv_days_ns$from,data_surv_days_ns$to)

tra.bws2 <- matrix(FALSE, 3, 3, dimnames = list(c(0, 1, 2), c(0, 1, 2)))
tra.bws2[1, 2:3] <- TRUE
tra.bws2[2, 3] <- TRUE
tra.bws2

#NEW TRANSITIONS
tra.bws2 <- matrix(FALSE,3,3)
tra.bws2 [1,2:3] <- TRUE
tra.bws2 [2,c(1,3)] <- TRUE
tra.bws2 <- matrix(FALSE,3,3)
tra.bws2 [1,2:3] <- TRUE
tra.bws2 [2,3] <- TRUE

##non-SMI with Daypatient Care
file_path <- "./output/survival_teilstationaer_non_severe.csv"
teilns <- read.csv(file_path)
#sex recode W-1;M-0
teilns$sex <- ifelse(teilns$sex == "W", 1, 0)
# Replace 99 with "cens" in the 'to' column
teilns$to[teilns$to == 99] <- "cens"

# table of possible transitions
table(teilns$from,teilns$to)

tra.bws22 <- matrix(FALSE, 3, 3, dimnames = list(c(0, 1, 2), c(0, 1, 2)))
tra.bws22[1, 2:3] <- TRUE
tra.bws22[2, 3] <- TRUE
tra.bws22

#NEW TRANSITIONS
tra.bws22 <- matrix(FALSE,3,3)
tra.bws22 [1,2:3] <- TRUE
tra.bws22 [2,c(1,3)] <- TRUE
tra.bws22 <- matrix(FALSE,3,3)
tra.bws22 [1,2:3] <- TRUE
tra.bws22 [2,3] <- TRUE

########################CI###############################
# nelson-aalen estimator of cumulative incidences
#inpatient severe
mvna.bws1 <- mvna(data_surv_days_sev, c("0", "1", "2"), tra.bws1, "cens")
summary(mvna.bws1)
line_colors <- c("yellow", "green","red")
plot(mvna.bws1, col = line_colors, xlab = "Days", main = "SMI", conf.int = TRUE)
#daypatient SMI
mvna.bws11 <- mvna(teil_sev, c("0", "1", "2"), tra.bws11, "cens")
summary(mvna.bws11)
line_colors <- c("lightblue", "darkgreen", "darkorange")
plot(mvna.bws11, col = line_colors, xlab = "Days", main = "SMI: DP", conf.int = TRUE)
#inpatient non-SMI
mvna.bws2 <- mvna(data_surv_days_ns, c("0", "1", "2"), tra.bws2, "cens")
summary(mvna.bws2)
line_colors <- c("yellow", "green","red")
plot(mvna.bws2, col = line_colors, cex = 0.80, xlab = "Days",
     main = "Inpatient Stay:non-SMI", lwd = 2, conf.int = T)
#daypatient non-SMI
mvna.bws22 <- mvna(teilns, c("0", "1", "2"), tra.bws22, "cens")
summary(mvna.bws22)
line_colors <- c("blue", "darkgreen","brown")
plot(mvna.bws22, col = line_colors, xlab = "Days", main = "non-SMI:DP", conf.int = T)

# aalen-johansen estimator of transition probablities
#inpatient SMI
etm.bws1 <- etm(data_surv_days_sev, c("0", "1", "2"), tra.bws1, "cens", s = 0)
setm <- summary(etm.bws1)
line_colors <- c("blue", "green", "red")
plot(etm.bws1, col = line_colors, legend = TRUE,
     legend.pos = "topright", xlab = "Days",
     cex = 0.30, main = "SMI", conf.int = TRUE)
summary (etm.bws1)

#daypatient SMI
etm.bws11 <- etm(teil_sev, c("0", "1", "2"), tra.bws11, "cens", s = 0)
setm <- summary(etm.bws11)
line_colors <- c("lightblue", "darkgreen", "darkorange")
plot(etm.bws11, col = line_colors, legend = TRUE,
     legend.pos = "topright", xlab = "Days",
     cex = 0.30, main = "SMI:DP", conf.int = TRUE)
summary (etm.bws11)

#inpatient non-SMI
etm.bws2 <- etm(data_surv_days_ns, c("0", "1", "2"), tra.bws2,
                "cens", s = 0)
line_colors <- c( "yellow", "green", "red" )
plot(etm.bws2, tr.choice = c("0 1", "0 2", "1 2"), col = line_colors,
     legend.pos = "topleft",
     xlab = "Days", cex = 0.8, main = "Inpatient Stay:non-SMI", lwd = 2,
     conf.int = TRUE)
summary(etm.bws2)
#daypatient non-SMI
etm.bws22 <- etm(teilns, c("0", "1", "2"), tra.bws2,
                 "cens", s = 0)
line_colors <- c( "lightblue", "darkgreen", "darkorange" )
plot(etm.bws22, tr.choice = c("0 1", "0 2", "1 2"), col = line_colors,
     legend.pos = "topleft",
     xlab = "Days", cex = 0.80, main = "Daypatient: non-SMI",
     lwd = 2, conf.int = T)
summary(etm.bws22)

#########################PLOTS WITHOUT CI###########################
#cumulative hazards
#inpatient severe
mvna.bws1 <- mvna(data_surv_days_sev, c("0", "1", "2"), tra.bws1, "cens")
summary(mvna.bws1)
line_colors <- c("yellow", "green","red")
plot(mvna.bws1, col = line_colors,cex = 0.80,xlab = "Days", main = "Inpatient Stay:SMI", lwd = 2)
#daypatient SMI
mvna.bws11 <- mvna(teil_sev, c("0", "1", "2"), tra.bws11, "cens")
summary(mvna.bws11)
line_colors <- c("lightblue", "darkgreen", "darkorange")
plot(mvna.bws11, col = line_colors,cex = 0.80,xlab = "Days",
     main = "Daypatient:SMI", lwd = 2)
#inpatient non-SMI
mvna.bws2 <- mvna(data_surv_days_ns, c("0", "1", "2"), tra.bws2, "cens")
summary(mvna.bws2)
line_colors <- c("yellow", "green","red")
plot(mvna.bws2, col = line_colors, cex = 0.80, xlab = "Days",
     main = "Inpatient Stay:non-SMI", lwd = 2)
#daypatient non-SMI
mvna.bws22 <- mvna(teilns, c("0", "1", "2"), tra.bws22, "cens")
summary(mvna.bws22)
line_colors <- c("lightblue", "darkgreen", "darkorange")
plot(mvna.bws22, col = line_colors, cex = 0.80, xlab = "Days",
     main = "Daypatient: non-SMI", lwd = 2)

#transitional probabilities
par(mfrow = c(1, 2))
#inpateint SMI
etm.bws1 <- etm(data_surv_days_sev, c("0", "1", "2"), tra.bws1, "cens", s = 0, covariance = F)
setm <- summary(etm.bws1)
line_colors <- c( "blue", "green", "red")
plot(etm.bws1, tr.choice = c("0 1", "0 2", "1 2"), col = line_colors,
     legend.pos = "topleft",
     xlab = "Days", cex = 0.80, main = "Inpatient Stay:SMI", lwd = 2)

#daypatient SMI
etm.bws11 <- etm(teil_sev, c("0", "1", "2"), tra.bws11, "cens", s = 0)
setm <- summary(etm.bws11)
line_colors <- c( "lightblue", "darkgreen", "orange")
plot(etm.bws11, tr.choice = c("0 1", "0 2", "1 2"), col = line_colors,
     legend.pos = "topleft",
     xlab = "Days", cex = 0.80, main = "Daypatient:SMI", lwd = 2)

#inpatient non-SMI
etm.bws2 <- etm(data_surv_days_ns, c("0", "1", "2"), tra.bws2,
                "cens", s = 0, covariance = F)
summary(etm.bws2)
line_colors <- c( "yellow", "green", "red" )
plot(etm.bws2, tr.choice = c("0 1", "0 2", "1 2"), col = line_colors,
     legend.pos = "topleft",
     xlab = "Days", cex = 0.8, main = "Inpatient Stay:non-SMI", lwd = 2)

#daypatient non-SMI
etm.bws22 <- etm(teilns, c("0", "1", "2"), tra.bws2,
                 "cens", s = 0, covariance = F)
summary(etm.bws22)
line_colors <- c( "lightblue", "darkgreen", "darkorange" )
plot(etm.bws22, tr.choice = c("0 1", "0 2", "1 2"), col = line_colors,
     legend.pos = "topleft",
     xlab = "Days", cex = 0.80, main = "Daypatient: non-SMI", lwd = 2)

#FIGURE 2
#cumulative hazards

par(mfrow = c(1, 2))
plot(mvna.bws1, tr.choice = c("1 2"), col = "red", cex = 1.5, xlab = "", ylab = "",
     lwd = 1.8, legend = FALSE, cex.axis = 1.2, ylim = c(0, 1))
lines(mvna.bws2, tr.choice = c("1 2"), col = "green", cex = 1.5, lwd = 1.8)
lines(mvna.bws11, tr.choice = c("1 2"), col = "blue", cex = 1.5, lwd = 1.8)
lines(mvna.bws22, tr.choice = c("1 2"), col = "yellow", cex = 1.5, lwd = 1.8)
par(family = "sans")
mtext("Cumulative Hazard", side = 2, line = 3, font = 2, cex = 1.6)
mtext("Days", side = 1, line = 3, font = 2, cex = 1.6)
legend(0.90, 0.95, legend=c('Inpatient:SMI', 'Inpatient:non-SMI','Daypatient:SMI',
                            'Daypatient:non-SMI'),
       col=c('red', 'green', 'blue', 'yellow'), lty = 1, cex = 1.2,
       y.intersp = 1, xjust = 0)

#transition probability
plot(etm.bws1, tr.choice = c("1 2"), col = "red", cex = 1.5, xlab = "", ylab = "",
     lwd = 1.8, legend = FALSE, cex.axis = 1.2)
lines(etm.bws2, tr.choice = c("1 2"), col = "green", cex = 1.5, lwd = 1.8)
lines(etm.bws11, tr.choice = c("1 2"), col = "blue", cex = 1.5, lwd = 1.8)
lines(etm.bws22, tr.choice = c("1 2"), col = "yellow", cex = 1.5, lwd = 1.8)
par(family = "sans")
mtext("Transition Probability", side = 2, line = 3, font = 2, cex = 1.6)
mtext("Days", side = 1, line = 3, font = 2, cex = 1.6)
legend(0.90, 0.95, legend=c('Inpatient:SMI', 'Inpatient:non-SMI','Daypatient:SMI',
                            'Daypatient:non-SMI'),
       col=c('red', 'green', 'blue', 'yellow'), lty = 1, cex = 1.2,
       y.intersp = 1, xjust = 0)

# Back to the original graphics device
par(mfrow = c(1, 1))

# Cox proportional hazards model
#initial to BW 01
cox.01 <- coxph(Surv(entry, exit, to == 1) ~ as.factor(severe) + as.factor(comorbidity)+ I(age/10) +
                  as.factor(sex), data_surv_days, subset = from == 0)
summary(cox.01)
cox.zph(cox.01)

#initial to Station 02
cox.02 <- coxph(Surv(entry, exit, to == 2) ~ as.factor(severe) + as.factor(comorbidity)+ I(age/10) +
                  as.factor(sex), data_surv_days, subset = from == 0)
summary(cox.02)
cox.zph(cox.02)

#BW to Station 12
cox.12 <- coxph(Surv(entry, exit, to == 2) ~  as.factor(severe) + as.factor(comorbidity) +I(age/10) +
                  as.factor(sex), teil_sev, subset = from == 1)

summary(cox.12)
cox.zph(cox.12)
