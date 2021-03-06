#' F Measure
#'
#' These functions calculate the [f_meas()] of a measurement system for
#' finding relevant documents compared to reference results
#' (the truth regarding relevance). Highly related functions are [recall()]
#' and [precision()].
#'
#' The measure "F" is a combination of precision and recall (see below).
#'
#' @family class metrics
#' @family relevance metrics
#' @templateVar metric_fn f_meas
#' @template event_first
#' @template multiclass
#' @template return
#' @template table-relevance
#'
#' @inheritParams sens
#'
#' @param beta A numeric value used to weight precision and
#'  recall. A value of 1 is traditionally used and corresponds to
#'  the harmonic mean of the two values but other values weight
#'  recall beta times more important than precision.
#'
#'
#' @references
#'
#' Buckland, M., & Gey, F. (1994). The relationship
#'  between Recall and Precision. *Journal of the American Society
#'  for Information Science*, 45(1), 12-19.
#'
#' Powers, D. (2007). Evaluation: From Precision, Recall and F
#'  Factor to ROC, Informedness, Markedness and Correlation.
#'  Technical Report SIE-07-001, Flinders University
#'
#' @author Max Kuhn
#'
#' @template examples-class
#'
#' @export
f_meas <- function(data, ...) {
  UseMethod("f_meas")
}

class(f_meas) <- c("class_metric", "function")
attr(f_meas, "direction") <- "maximize"

#' @rdname f_meas
#' @export
f_meas.data.frame <- function(data, truth, estimate, beta = 1,
                              estimator = NULL, na_rm = TRUE, ...) {

  metric_summarizer(
    metric_nm = "f_meas",
    metric_fn = f_meas_vec,
    data = data,
    truth = !!enquo(truth),
    estimate = !!enquo(estimate),
    estimator = estimator,
    na_rm = na_rm,
    ... = ...,
    metric_fn_options = list(beta = beta)
  )

}

#' @export
f_meas.table <- function (data, beta = 1, estimator = NULL, ...) {
  check_table(data)
  estimator <- finalize_estimator(data, estimator)

  metric_tibbler(
    .metric = "f_meas",
    .estimator = estimator,
    .estimate = f_meas_table_impl(data, estimator, beta = beta)
  )
}

#' @export
f_meas.matrix <- function(data, beta = 1, estimator = NULL, ...) {

  data <- as.table(data)
  f_meas.table(data, beta, estimator)

}

#' @export
#' @rdname f_meas
f_meas_vec <- function(truth, estimate, beta = 1,
                       estimator = NULL, na_rm = TRUE, ...) {

  estimator <- finalize_estimator(truth, estimator)

  f_meas_impl <- function(truth, estimate, beta) {

    xtab <- vec2table(
      truth = truth,
      estimate = estimate
    )

    f_meas_table_impl(xtab, estimator, beta = beta)

  }

  metric_vec_template(
    metric_impl = f_meas_impl,
    truth = truth,
    estimate = estimate,
    na_rm = na_rm,
    estimator = estimator,
    cls = "factor",
    ...,
    beta = beta
  )

}

f_meas_table_impl <- function(data, estimator, beta = 1) {

  if(is_binary(estimator)) {
    f_meas_binary(data, beta)
  } else {
    w <- get_weights(data, estimator)
    out_vec <- f_meas_multiclass(data, estimator, beta)
    weighted.mean(out_vec, w, na.rm = TRUE)
  }

}

f_meas_binary <- function(data, beta = 1) {

  precision <- precision_binary(data)
  rec <- recall_binary(data)

  # if precision and recall are both 0, return 0 not NA
  if(isTRUE(precision == 0 & rec == 0)) {
    return(0)
  }

  (1 + beta ^ 2) * precision * rec / ((beta ^ 2 * precision) + rec)
}

f_meas_multiclass <- function(data, estimator, beta = 1) {

  precision <- precision_multiclass(data, estimator)
  rec <- recall_multiclass(data, estimator)

  res <- (1 + beta ^ 2) * precision * rec / ((beta ^ 2 * precision) + rec)

  # if precision and recall are both 0, define this as 0 not NA
  # this is the case when tp == 0 and is well defined
  # Matches sklearn behavior
  # https://github.com/scikit-learn/scikit-learn/blob/bac89c253b35a8f1a3827389fbee0f5bebcbc985/sklearn/metrics/classification.py#L1150
  where_zero <- which(precision == 0 & rec == 0)

  res[where_zero] <- 0

  res
}
