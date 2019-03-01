#' Simulation Plot with ggplot: The true beta, relevant component and eigen structure
#' @keywords simrel-plot, simulation plot, simulation ggplot
#' @import ggplot2
#' @param obj A simrel object
#' @param ncomp Number of components to plot
#' @param layout A layout matrix of how to layout multiple plots
#' @param print.cov Output estimated covariance structure
#' @param which A character indicating which plot you want as output, it can take \code{TrueBeta}, \code{RelComp} and \code{EstRelComp}
#' @param use_population Logical, TRUE if population values should be used and FALSE if sample values should be used
#' @return A list of plots
#' @examples
#' sim.obj <- simrel(n = 100, p = 16, q = c(3, 4, 5),
#'    relpos = list(c(1, 2), c(3, 4), c(5, 7)), m = 5,
#'    ypos = list(c(1, 4), 2, c(3, 5)), type = "multivariate",
#'    R2 = c(0.8, 0.7, 0.9), gamma = 0.8)
#'
#' ggsimrelplot(sim.obj, layout = matrix(c(2, 1, 3, 1), 2))
#'
#' ggsimrelplot(sim.obj, which = c(1, 2), use_population = TRUE)
#'
#' ggsimrelplot(sim.obj, which = c(1, 2), use_population = FALSE)
#'
#' ggsimrelplot(sim.obj, which = c(1, 3), layout = matrix(c(1, 2), 1))
#' @export

ggsimrelplot <- function(obj, ncomp = min(obj$p, obj$n, 20), which = 1L:3L,
           layout = NULL, print.cov = FALSE, use_population = TRUE) {
    nx <- obj$p
    ny <- ncol(obj$Y)
    xticks <- 1:nx
    if (is.null(which)) which <- 1L:3L
    if (is.null(layout) & length(which) == 3) layout <- matrix(c(2, 1, 3, 1), 2)


    plt1 <- expression({
    ## Plot1: True Coefficients Plot
    beta <- `dimnames<-`(
      obj$beta, list(c(1:nx), c(paste0("Y", 1:ny))))
    beta_stk <- `names<-`(
      reshape2::melt(beta), c("Predictor", "Response", "BetaCoef"))
    plt1 <- ggplot(
      beta_stk,
      aes(Predictor, BetaCoef,
          color = Response,
          group = Response)) +
      geom_hline(yintercept = 0,
                 color = "grey2",
                 linetype = 2) +
      geom_line() +
      geom_point() +
      scale_x_continuous(breaks = xticks) +
      labs(x = "Variable Number",
           y = expression(paste("Regression Coefficients (", beta, ")"))) +
      ggtitle("True Regression Coefficients") +
      theme(legend.position = if (ny == 1) "none" else "bottom") +
      scale_color_brewer(palette = 'Set1')
    })

    plt2 <- expression({
    ## Plot 2: Relevant Comoponents Plot
    idx <- if (obj$type == "univariate") 1 else ny
    covs <- obj$Sigma[-c(1:idx), 1:idx, drop = FALSE]
    if (obj$type == "multivariate") {
      covs <- obj$SigmaWZ[-c(1:idx), 1:idx, drop = FALSE]
    }
    ## DoNot normalize for response ----
    # covs.sc <- apply(covs, 2, function(x) {
    #   out <- abs(x)/max(abs(x))
    #   out[is.nan(out)] <- 0
    #   return(out)
    # })
    ## End DoNot -----
    ## Normalize by overall maximum value ------
    covs.sc <- abs(covs)/max(abs(covs))
    ## End Normalize -------
    covs.dt <- as.data.frame(
      cbind(
        1:ncomp,
        obj$lambda[1:ncomp],
        covs.sc[1:ncomp, ]
      ), 1
    )
    names(covs.dt) <- c("comp", "lambda", paste0("W", 1:ny))
    covs.stk <- reshape2::melt(
      covs.dt, 1:2,
      variable.name = "response",
      value.name = "covariance"
    )
    pjtr <- position_dodge(0.5)
    plt2 <- ggplot(
      covs.stk,
      aes(comp, covariance, color = response, group = response)) +
      geom_bar(data = covs.dt,
               aes(x = comp, y = lambda),
               inherit.aes = FALSE,
               stat = "identity",
               fill = "lightgrey") +
      geom_line(position = pjtr) +
      geom_point(position = pjtr) +
      labs(x = "Components",
           y = "Covariance (absolute value)/ Eigenvalue") +
      theme(legend.position = if (ny == 1) "none" else "bottom") +
      ggtitle("Relevant Components Plot") +
      scale_x_continuous(breaks = xticks) +
      coord_cartesian(xlim = c(1, ncomp)) +
      scale_color_brewer(ifelse(obj$type == "multivariate",
                           "Response Component", "Response"),
                         palette = 'Set1')
    })

    est.covs <- expression({
      covs <- if (use_population) {
          eigval <- obj$lambda
          eigval.sc <- eigval/eigval[1]
          covs <- switch(
            obj$type,
            univariate = {
              m <- 1
              rot <- obj$Rotation
              covs <- obj$Sigma[-c(1:m), 1:m, drop = FALSE]
              covs <- abs(rot %*% covs)
            },
            bivariate = {
              m <- 2
              covs <- obj$Sigma[-c(1:m), c(1:m), drop = FALSE]
              covs <- abs(covs)
            },
            multivariate = abs(t(obj$SigmaYZ))
          )
        } else {
          X <- scale(obj$X, center = TRUE, scale = FALSE)
          Y <- scale(obj$Y, center = TRUE, scale = FALSE)

          svdres <- svd(X)
          eigval <- (svdres$d ^ 2)/(obj$n - 1)  #/(svdres$d ^ 2)[1]
          eigval.sc <- eigval/eigval[1]

          Z <- X %*% svdres$v
          covs <- t(abs(cov(Y, Z)))
        }
    })

    plt3 <- expression({
    ## Plot 3: Estimated Relevant Component Plot
    eval(est.covs)
    ## Normalize by overall maximum value ------
    covs.sc <- abs(covs)/max(abs(covs))
    # covs.sc <- apply(covs, 2, function(x) abs(x)/max(abs(x)))
    ## End Normalize -------
    covs.dt <- as.data.frame(
      cbind(1:ncomp,
            eigval.sc[1:ncomp],
            covs.sc[1:ncomp, ]),
      1)
    names(covs.dt) <- c("comp", "lambda", paste0("Y", 1:ny))
    covs.stk <- reshape2::melt(
      covs.dt, 1:2,
      variable.name = "response",
      value.name = "covariance"
    )
    pjtr <- position_dodge(0.5)
    plt3 <- ggplot(
      covs.stk,
      aes(comp, covariance, color = response, group = response)) +
      geom_bar(data = covs.dt,
               aes(x = comp, y = lambda),
               inherit.aes = FALSE,
               stat = "identity",
               fill = "lightgrey") +
      geom_line(position = pjtr) +
      geom_point(position = pjtr) +
      labs(x = "Components",
           y = "Covariance (absolute value)/ Eigenvalue") +
      theme(legend.position = if (ny == 1) "none" else "bottom") +
      ggtitle("Estimated relevant components plot") +
      scale_x_continuous(breaks = xticks) +
      coord_cartesian(xlim = c(1, ncomp)) +
      scale_color_brewer("Response", palette = 'Set1')
    })

    est.covs.xy <- expression({
      covs <- if (use_population) {
          covs <- if(obj$type == "multivariate") {
            abs(t(obj$SigmaYX))
          } else {
            m <- ifelse(obj$type == 'univariate', 1, 2)
            p <- obj$p
            covs <- obj$Sigma[-c(1:m), c(1:m), drop = FALSE]
            covs <- abs(covs)
          }
        } else {
          X <- scale(obj$X, center = TRUE, scale = FALSE)
          Y <- scale(obj$Y, center = TRUE, scale = FALSE)
          covs <- t(abs(cov(Y, X)))
        }
    })

    plt4 <- expression({
      ## Plot 3: Estimated Relevant Component Plot
      eval(est.covs.xy)
      ## Normalize by overall maximum value ------
      covs.sc <- abs(covs)/max(abs(covs))
      # covs.sc <- apply(covs, 2, function(x) abs(x)/max(abs(x)))
      ## End Normalize -------
      covs.dt <- as.data.frame(cbind(1:obj$p, covs.sc[1:ncomp, ]), 1)
      names(covs.dt) <- c("predictors", paste0("Y", 1:ny))
      covs.stk <- reshape2::melt(
        covs.dt, 1,
        variable.name = "response",
        value.name = "covariance"
      )
      pjtr <- position_dodge(0.5)
      plt4 <- ggplot(
        covs.stk,
        aes(predictors, covariance, color = response, group = response)) +
        geom_line(position = pjtr) +
        geom_point(position = pjtr) +
        labs(x = "Predictors",
             y = "abs(covariance) between Predictor & Response") +
        theme(legend.position = if (ny == 1) "none" else "bottom") +
        ggtitle("Estimated Covariance plot") +
        scale_x_continuous(breaks = xticks) +
        coord_cartesian(xlim = c(1, ncomp)) +
        scale_color_brewer("Response", palette = 'Set1')
    })

    plt <- list(
      TrueBeta = plt1,
      RelComp = plt2,
      EstRelComp = plt3,
      EstCov = plt4
    )

    if (length(which) == 1) {
      out <- eval(plt[[which]])
    } else {
      plts <- lapply(which, function(i) eval(plt[[i]]))
      names(plts) <- names(plt)[which]

      if (length(which) == 2 & is.null(layout)) layout <- matrix(c(1, 2), 2)
      if (length(which) > length(layout)) layout <- matrix(1:length(which), length(which))

      plts$layout_matrix <- layout
      out <- do.call(gridExtra::grid.arrange, plts)
    }

    if (print.cov) {
      eval(est.covs)
      covs <- covs[1:min(ncomp, nx), ]
      dimnames(covs) <- list(
        paste0("Component", 1:min(ncomp, nx)),
        paste0("Response", 1:ny)
      )
      attr(out, "covariance") <- covs
      cat("Absolute values of estimated covariances\n")
      print(covs)
    }

    if (length(which) == 1) return(out) else return(invisible(out))
  }
