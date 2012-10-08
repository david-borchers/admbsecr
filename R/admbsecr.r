## admbsecr() takes capture history and mask objects from the secr
## package and fits an SECR model using ADMB.
admbsecr <- function(capt, capt2 = NULL, traps, mask, sv = "auto", ssqtoa = NULL,
                     angs = NULL, cutoff = NULL, admbwd = NULL, method = "simple",
                     memory = NULL, profpars = NULL, clean = TRUE,
                     verbose = TRUE, trace = FALSE, autogen = FALSE){
  require(R2admb)
  require(secr)
  ## Warnings for incorrect input.
  if (length(method) != 1){
    stop("method must be of length 1")
  }
  if (method == "simple" & any(capt != 1 & capt != 0)){
    stop('capt must be binary when using the "simple" method')
  }
  if (method == "ss" & is.null(cutoff)){
    stop("cutoff must be supplied for signal strength analysis")
  }
  if (trace){
    verbose <- TRUE
  }
  trace <- as.numeric(trace)
  currwd <- getwd()
  ## Moving to ADMB working directory.
  if (!is.null(admbwd)){
    setwd(admbwd)
  }
  if (autogen){
    prefix <- "secr"
    make.all.tpl(memory = memory, methods = method)
  } else {
    prefix <- paste(method, "secr", sep = "")
  }
  ## If NAs are present in capture history object, change to zeros.
  capt[is.na(capt)] <- 0
  ## Extracting no. animals trapped (n) and traps (k) from capture history array.
  ## Only currently works with one capture session.
  n <- dim(capt)[1]
  k <- dim(capt)[3]
  ## Area covered by each mask location.
  A <- attr(mask, "area")
  bincapt <- capt
  bincapt[capt > 0] <- 1
  ## Setting number of model parameters.
  npars <- c(3[method == "simple"], 4[method %in% c("toa", "ang", "ss")])
  ## Setting sensible start values if elements of sv are "auto".
  if (length(sv) == 1 & sv[1] == "auto"){
    sv <- rep("auto", npars)
  }
  if (any(sv == "auto")){
    ## Give sv vector names if it doesn't have them.
    if (is.null(names(sv))){
      names(sv) <- c("D", "g0"[!(method == "ss" | method == "sstoa")],
                     "sigma"[!(method == "ss" | method == "sstoa")],
                     "sigmatoa"[method == "toa" | method == "sstoa"],
                     "kappa"[method == "ang"],
                     "ssb0"[method == "ss" | method == "sstoa"],
                     "ssb1"[method == "ss" | method == "sstoa"],
                     "sigmass"[method == "ss" | method = "sstoa"])
    } else {
      ## Reordering sv vector if names are provided.
      sv <- sv[c("D", "g0"[!(method == "ss" | method == "sstoa")],
                 "sigma"[!(method == "ss" | method == "sstoa")],
                 "sigmatoa"[method == "toa" | method == "sstoa"],
                 "kappa"[method == "ang"],
                 "ssb0"[method == "ss" | method == "sstoa"],
                 "ssb1"[method == "ss" | method == "sstoa"],
                 "sigmass"[method = "ss" | method == "sstoa"])]
    }
    autofuns <- list("D" = autoD, "g0" = autog0, "sigma" = autosigma,
                     "sigmatoa" = autosigmatoa, "kappa" = autokappa,
                     "ssb0" = autossb0, "ssb1" = autossb1,
                     "sigmass" = autosigmass)
    ## Replacing "auto" elements of sv vector.
    for (i in rev(which(sv == "auto"))){
      sv[i] <- autofuns[[names(sv)[i]]](capt, bincapt, traps, mask, sv, method)
    }
    sv <- as.numeric(sv)
  }
  ## Removing attributes from capt and mask objects as do_admb cannot handle them.
  bincapt <- matrix(as.vector(bincapt), nrow = n, ncol = k)
  capt <- matrix(as.vector(capt), nrow = n, ncol = k)
  mask <- as.matrix(mask)
  ## No. of mask locations.
  nm <- nrow(mask)
  ## Distances between traps and mask locations.
  dist <- distances(traps, mask)
  traps <- as.matrix(traps)
  ## Setting up parameters for do_admb.
  if (method == "simple"){
    data <- list(n = n, ntraps = k, nmask = nm, A = A, capt = capt,
                 dist = dist, traps = traps, trace = trace)
    params <- list(D = sv[1], g0 = sv[2], sigma = sv[3])
    bounds <- list(D = c(0, 10000000), g0 = c(0, 1), sigma = c(0, 100000))
  } else if (method == "toa"){
    if (is.null(ssqtoa)){
      ssqtoa <- apply(capt, 1, toa.ssq, dists = dist)
    }
    data <- list(n = n, ntraps = k, nmask = nm, A = A, toacapt = capt,
                 toassq = t(ssqtoa), dist = dist, capt = bincapt, trace = trace)
    params <- list(D = sv[1], g0 = sv[2], sigma = sv[3], sigmatoa = sv[4])
    bounds <- list(D = c(0, 10000000), g0 = c(0, 1), sigma = c(0, 100000),
                   sigmatoa = c(0, 100000))
  } else if (method == "ang"){
    if (is.null(angs)){
      angs <- angles(traps, mask)
    }
    data <- list(n = n, ntraps = k, nmask = nm, A = A, angcapt = capt,
                 ang = angs, dist = dist, capt = bincapt, trace = trace)
    params <- list(D = sv[1], g0 = sv[2], sigma = sv[3], kappa = sv[4])
    bounds <- list(D = c(0, 10000000), g0 = c(0, 1), sigma = c(0, 100000),
                   kappa = c(0, 700))
  } else if (method == "ss"){
    data <- list(n = n, ntraps = k, nmask = nm, A = A, c = cutoff, sscapt = capt,
                 dist = dist, capt = bincapt, trace = trace)
    params <- list(D = sv[1], ssb0 = sv[2], ssb1 = sv[3], sigmass = sv[4])
    bounds <- list(D = c(0, 10000000), sigmass = c(0, 100000), ssb1 = c(-100000, 0))
  } else if (method == "sstoa"){
    data <- list(n = n, ntraps = k, nmask = nm, A = A, c = cutoff, sscapt = capt[, , 1],
                 toacapt = capt[, , 2], toassq = t(ssqtoa), dist = dist, capt = bincapt,
                 trace = trace)
    params <- list(D = sv[1], sigmatoa = sv[2], ssb0 = sv[3], ssb1 = sv[4], sigmass = sv[5])
    bounds <- list(D = c(0, 10000000), sigmass = c(0, 100000), ssb1 = c(-100000, 0),
                   sigmatoa = c(0, 100000))
  } else {
    stop('method must be either "simple", "toa", "ang" or "ss"')
  }
  ## Fitting the model.
  if (!is.null(profpars)){
    fit <- do_admb(prefix, data = data, params = params, bounds = bounds, verbose = verbose,
                   profile = FALSE, profpars = profpars, safe = TRUE,
                   run.opts = run.control(checkdata = "write", checkparam = "write",
                     clean = clean))
  } else {
    fit <- do_admb(prefix, data = data, params = params, bounds = bounds, verbose = verbose,
                   safe = FALSE,
                   run.opts = run.control(checkdata = "write", checkparam = "write",
                     clean = clean))
  }
  if (autogen){
    file.remove("secr.tpl")
  }
  setwd(currwd)
  fit
}
