## Letting R know where everything is.
admbsecr.dir <- "~/admbsecr" # Point this to the admbsecr file.
if (.Platform$OS == "unix"){
  sep <- "/"
} else if (.Platform$OS == "windows") {
  sep <- "\\"
}
admb.dir <- paste(admbsecr.dir, "ADMB", sep = sep)
work.dir <- paste(admbsecr.dir, "Analysis", sep = sep)
dat.dir <- paste(admbsecr.dir, "Data", sep = sep)

## Get required library.
library(secr)

## Loading the admbsecr library.
setwd(admbsecr.dir)
library(devtools)
load_all(".")
##library(admbsecr)

## Creating trap objects.
fake.traps <- data.frame(name = 1:2, x = c(1e-3, -1e-3), y = c(-1e-3, 1e-3))
real.traps <- data.frame(name = 1:2, x = rep(0, 2), y = rep(0, 2))
fake.traps <- read.traps(data = fake.traps, detector = "proximity")
options(warn = -1)
real.traps <- read.traps(data = real.traps, detector = "proximity")
options(warn = 1)

setwd(work.dir)
## setup for simulations.
nsims <- 2
buffer <- 3000
mask.spacing <- 45

## True parameter values.
seed <- 8465
D <- 1.7
g01 <- 0.99999
sigma1 <- 210
g02 <- 0.30
sigma2 <- 320
alpha <- 26
truepars <- c(D = D, g01 = g01, sigma1 = sigma1, g02 = g02,
              sigma2 = sigma2, alpha = alpha)
detectpars <- list(g01 = g01, sigma1 = sigma1, g02 = g02,
                   sigma2 = sigma2, alpha = alpha)

set.seed(seed)

## Setting up mask.
mask <- make.mask(fake.traps, buffer = buffer, spacing = mask.spacing,
                  type = "trapbuffer")

## Results matrices.
distres <- matrix(0, nrow = nsims, ncol = 6)
colnames(distres) <- c("D", "g01", "sigma1", "g02", "sigma2", "alpha")
mrdsres <- matrix(0, nrow = nsims, ncol = 5)
colnames(mrdsres) <- c("D", "g01", "sigma1", "g02", "sigma2")
distprobs <- NULL
mrdsprobs <- NULL

## Carrying out simulation.
for (i in 1:nsims){
  if (i == 1){
    print(c("start", date()))
  } else {
    print(c(i, date()))
  }
  ## Simulating data and setting things up for analysis.
  popn <- sim.popn(D = D, core = real.traps, buffer = buffer)
  capthists <- sim.capthist.dist(real.traps, popn, detectpars)
  capthist.dist <- capthists$dist
  capthist.mrds <- capthists$mrds
  distfit <- disttrapcov(capt = capthist.dist, mask = mask, traps = real.traps,
                         sv = c(D, g01, sigma1, g02, sigma2, alpha),
                         admb.dir = admb.dir, clean = TRUE,
                         verbose = FALSE, trace = FALSE)
  mrdsfit <- mrdstrapcov(capt = capthist.mrds, mask = mask, traps = real.traps,
                         sv = c(D, g01, sigma1, g02, sigma2), admb.dir = admb.dir,
                         clean =  TRUE, verbose = FALSE, trace = FALSE)
  if (class(distfit) == "try-error"){
    distcoef <- NA
    distprobs <- c(distprobs, i)
  } else {
    distcoef <- coef(distfit)
  }
  if (class(mrdsfit) == "try-error"){
    mrdscoef <- NA
    mrdsprobs <- c(mrdsprobs, i)
  } else {
    mrdscoef <- coef(mrdsfit)
  }
  distres[i, ] <- distcoef
  mrdsres[i, ] <- mrdscoef
}

## ## To write the simulation results to a file.
## distrespath <- paste(admbsecr.dir, "Results/whales/2/distres.txt", sep = "/")
## mrdsrespath <- paste(admbsecr.dir, "Results/whales/2/mrdsres.txt", sep = "/")
## write.table(distres, distrespath, row.names = FALSE)
## write.table(mrdsres, mrdsrespath, row.names = FALSE)

## To read in simulation results from a file.
resfile <- "~/admbsecr/Results/whales/2/"
source(paste(resfile, "pars.r", sep = ""))
distres <- read.table(paste(resfile, "distres.txt", sep = ""), header = TRUE)
mrdsres <- read.table(paste(resfile, "mrdsres.txt", sep = ""), header = TRUE)

## Assigning the columns to vectors.
for (i in colnames(distres)){
  name <- paste("dist", i, sep = "")
  assign(name, distres[, i])
  dname <- paste("ddist", i, sep = "")
  assign(dname, density(get(name)))
}
for (i in colnames(mrdsres)){
  name <- paste("mrds", i, sep = "")
  assign(name, mrdsres[, i])
  dname <- paste("dmrds", i, sep = "")
  assign(dname, density(get(name)))
}

xs <- c(ddistD$x, dmrdsD$x)
ys <- c(ddistD$y, dmrdsD$y)

##pdf(file = paste(resfile, "fig", sep = ""))
plot.new()
plot.window(xlim = range(xs), ylim = c(0, max(ys)))
axis(1)
axis(2, las = 1)
abline(v = D, lty = "dotted")
lines(ddistD, col = "blue")
lines(dmrdsD, col = "red")
abline(h = 0, col = "grey")
box()
title(main = "Simulated sampling distributions of animal density",
      xlab = expression(hat(D)), ylab = "Density")
legend(x = "topright", legend = c("SECR + Distances", "MRDS"),
       col = c("blue", "red"), lty = 1)
##dev.off()
