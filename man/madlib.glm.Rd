\name{madlib.glm}
\alias{madlib.glm}

\title{

    Generalized Linear Regression by MADlib in databases

}

\description{

    The wrapper function for MADlib's generzlized linear regression [7]
    including the support for multple families and link functions.
    Heteroskedasticity test is implemented for linear regression. One or
    multiple columns of data can be used to separate the data set into multiple
    groups according to the values of the grouping columns. The requested
    regression method is applied onto each group,  which has fixed values of
    the grouping columns. Multinomial logistic regression is not implemented
    yet. Categorical variables are supported. The computation is parallelized
    by MADlib if the connected database is Greenplum/HAWQ database. The
    regression computation can also be done on a column which contains an array
    as its value in the data table.

}

\usage{

madlib.glm(formula, data, family = gaussian, na.action = NULL, control
           = list(), ...)

}

\arguments{

    \item{formula}{

        An object of class \code{\link{formula}} (or one that can be coerced to
        that class): a symbolic description of the model to be fitted. The
        details of model specification are given under `Details'.

    }

    \item{data}{

        An object of \code{db.obj} class. Currently, this parameter is
        mandatory. If it is an object of class \code{db.Rquery} or
        \code{db.view}, a temporary table will be created, and further
        computation will be done on the temporary table. After the computation,
        the temporary will be dropped from the corresponding database.

    }

    \item{family}{

        A string which indicates which form of regression to apply. Default
        value is ``\code{gaussian}''. The accepted values are:
        \code{gaussian(identity)} (default for \code{gaussian} family),
        \code{gaussian(log)}, \code{gaussian(inverse)}, \code{binomial(logit)}
        (default for \code{binomial} family), \code{binomial(probit)},
        \code{poisson(log)} (default for \code{poisson} family),
        \code{poisson(identity)}, \code{poisson(sqrt)}, \code{Gamma(inverse)}
        (default for \code{Gamma} family), \code{Gamma(identity)},
        \code{Gamma(log)}, \code{inverse.gaussian(1/mu^2)} (default for
        \code{inverse.gaussian} family), \code{inverse.gaussian(log)},
        \code{inverse.gaussian(identity)}, \code{inverse.gaussian(inverse)}.}

    \item{na.action}{

        A string which indicates what should happen when the data contain
        \code{NA}s. Possible values include \code{\link{na.omit}},
        \code{"na.exclude"}, \code{"na.fail"} and \code{NULL}. Right now,
        \code{\link{na.omit}} has been implemented. When the value is
        \code{NULL}, nothing is done on the R side and \code{NA} values are
        filtered on the MADlib side. User defined \code{na.action} function is
        allowed.

    }

    \item{control}{

        A list, extra parameters to be passed to linear or logistic
        regressions.

        \code{na.as.level}: A logical value, default is \code{FALSE}. Whether
        to treat \code{NA} value as a level in a categorical variable or just
        ignore it.

        For the linear regressions, the extra parameter is
        \code{hetero}. A logical, deafult is \code{FALSE}. If it is
        \code{TRUE}, then Breusch-Pagan test is performed on the fitting model and
        the corresponding test statistic and p-value are computed.

        For logistic regression, one can pass the following extra parameters:

        \code{method}: A string, default is \code{"irls"} (iteratively
        reweighted least squares [3]), other choices
        are \code{"cg"} (conjugate gradient descent algorithm [4]) and
        \code{"igd"} (stochastic gradient descent algorithm [5]). These
        algorithm names for logistic regression, namely
        \code{family=binomial(logit)} and \code{use.glm=FALSE} in the
        control list.

        \code{max.iter}: An integer, default is 10000. The maximum number of
        iterations that the algorithms will run.

        \code{tolerance}: A numeric value, default is 1e-5. The stopping
        threshold for the iteration algorithms.

        \code{use.glm}: Whether to call MADlib's GLM function even when the
        family is \code{gaussian(identity)} or \code{binomial(logit)}. For
        these two cases, the default behavior is to call MADlib's linear
        regression or logistic regression respectively, which might give better
        performance under certain circumstances. However, if \code{use.glm} is
        \code{TRUE}, then the generalized linear function will be used.

    }

    \item{\dots}{

        Further arguments passed to or from other methods. Currently, no more
        parameters can be passed to the linear regression and logistic
        regression.

    }

}

\details{

  See \code{\link{madlib.lm}} for more details.

}

\value{

  For the return value of linear regression see \code{\link{madlib.lm}}
  for details.

  For the logistic regression, the returned value is similar to that of
  the linear regression.  If there is no grouping (i.e. no \code{|} in the
  formula), the result is a \code{logregr.madlib} object. Otherwise, it is
  a \code{logregr.madlib.grps} object, which is just a list of
  \code{logregr.madlib} objects.

  If MADlib's generalized linear regression function is used
  (\code{use.glm=TRUE} for \code{family=binomial(logit)}), the return
  value is a \code{glm.madlib} object without grouping or
  a \code{glm.madlib.grps} object with grouping.

  A \code{logregr.madlib} or \code{glm.madlib} object is a list which
  contains the following items:

  \item{grouping column(s)}{

      When there are grouping columns in the formula, the resulting list
      has multiple items, each of which has the same name as one of the
      grouping columns. All of these items are vectors, and they have the
      same length, which is equal to the number of distinct combinations
      of all the grouping column values. Each row of these items together
      is one distinct combination of the grouping values. When there is no
      grouping column in the formula, none of such items will appear in
      the resulting list.

  }

  \item{coef}{

    A numeric matrix, the fitting coefficients. Each row contains the
    coefficients for the linear regression of each group of data. So the
    number of rows is equal to the number of distinct combinations of all
    the grouping column values.

  }

  \item{log_likelihood}{

    A numeric array, the log-likelihood for each fitting to the groups.
    Thus the length of the array is equal to \code{grps}.

  }

  \item{std_err}{

    A numeric matrix, the standard error for each coefficients. The row
    number is equal to \code{grps}.

  }

  \item{z_stats,t_stats}{

    A numeric matrix, the z-statistics or t-statistics for each
    coefficient. Each row is for a fitting to a group of the data.

  }

  \item{p_values}{

      A numeric matrix, the p-values of \code{z_stats}. Each row is for
      a fitting to a group of the data.

  }

  \item{odds_ratios}{

    Only for \code{logregr.madlib} object. A numeric array, the odds
    ratios [6] for the fittings for all groups.

  }

  \item{condition_no}{

     Only for \code{logregr.madlib} object. A numeric array, the condition
    number for all combinations of the grouping column values.

  }

  \item{num_iterations}{

      An integer array, the itertion number used by each fitting group.

  }

  \item{grp.cols}{

    An array of strings. The column names of the grouping columns.

  }

  \item{has.intercept}{

    A logical, whether the intercept is included in the fitting.

  }

  \item{ind.vars}{

       An array of strings, all the different terms used as independent
    variables in the fitting.

  }

  \item{ind.str}{

    A string. The independent variables in an array format string.

  }

  \item{call}{

    A language object. The function call that generates this result.

  }

  \item{col.name}{

      An array of strings. The column names used in the fitting.

  }

  \item{appear}{

       An array of strings, the same length as the number of independent
    variables. The strings are used to print a clean result, especially when
    we are dealing with the factor variables, where the dummy variable
    names can be very long due to the inserting of a random string to
    avoid naming conflicts, see \code{\link{as.factor,db.obj-method}}
    for details. The list also contains \code{dummy} and \code{dummy.expr},
    which are also used for processing the categorical variables, but do not
    contain any important information.

  }

  \item{model}{

    A \code{\linkS4class{db.data.frame}} object, which wraps the result
    table of this function.

  }

  \item{terms}{

      A \code{\link{terms}} object, describing the terms in the model formula.

  }

  \item{nobs}{

    The number of observations used to fit the model.

  }

  \item{data}{

      A \code{db.obj} object, which wraps all the data used in the database. If
      there are fittings for multiple groups,   then this is only the wrapper
      for the data in one group.

  }

  \item{origin.data}{

      The original \code{db.obj} object. When there is no grouping, it is equal
      to \code{data} above, otherwise it is the "sum" of \code{data} from all
      groups.

  }

  Note that if there is grouping done, and there are multiple
  \code{logregr.madlib} objects in the final result, each one of them
  contains the same copy \code{model}.

}

\author{

    Author: Predictive Analytics Team at Pivotal Inc.

    Maintainer: Frank McQuillan, Pivotal Inc. \email{fmcquillan@pivotal.io}

}

\note{

    See \code{\link{madlib.lm}}'s note for more about the formula format.

  For logistic regression, the dependent variable MUST be a logical
  variable with values being \code{TRUE} or \code{FALSE}.

}

\references{

    [1] Documentation of linear regression in lastest MADlib,
    \url{https://madlib.apache.org/docs/latest/group__grp__linreg.html}

    [2] Documentation of logistic regression in latest MADlib,
    \url{https://madlib.apache.org/docs/latest/group__grp__logreg.html}

    [3] Wikipedia: Iteratively reweighted least squares,
    \url{https://en.wikipedia.org/wiki/IRLS}

    [4] Wikipedia: Conjugate gradient method,
    \url{https://en.wikipedia.org/wiki/Conjugate_gradient_method}

    [5] Wikipedia: Stochastic gradient descent,
    \url{https://en.wikipedia.org/wiki/Stochastic_gradient_descent}

    [6] Wikipedia: Odds ratio, \url{https://en.wikipedia.org/wiki/Odds_ratio}

    [7] Documentation of generalized linear regression in latest MADlib,
    \url{https://madlib.apache.org/docs/latest/group__grp__glm.html}

}

\seealso{

    \code{\link{madlib.lm}}, \code{\link{madlib.summary}},
    \code{\link{madlib.arima}} are MADlib wrapper functions.

    \code{\link{as.factor}} creates categorical variables for fitiing.

    \code{\link{delete}} safely deletes the result of this function.

}

\examples{

\dontrun{

%% @test .port Database port number
%% @test .dbname Database name
## set up the database connection
## Assume that .port is port number and .dbname is the database name
cid <- db.connect(port = .port, dbname = .dbname, verbose = FALSE)

source_data <- as.db.data.frame(abalone, conn.id = cid, verbose = FALSE)

lk(source_data, 10)

## linear regression conditioned on nation value
## i.e. grouping
fit <- madlib.glm(rings ~ . -id | sex, data = source_data, heteroskedasticity = T)
fit

## logistic regression

## logistic regression
## The dependent variable must be a logical variable
## Here it is y < 10.
fit <- madlib.glm(rings < 10 ~ . - id - 1 , data = source_data, family = binomial)

fit <- madlib.glm(rings < 10 ~ sex + length + diameter,
data = source_data, family = "logistic")

## 3rd example
## The table has two columns: x is an array, y is double precision
dat <- source_data
dat$arr <- db.array(source_data[,-c(1,2)])
array.data <- as.db.data.frame(dat)

## Fit to y using every element of x
## This does not work in R's lm, but works in madlib.lm
fit <- madlib.glm(rings < 10 ~ arr, data = array.data, family = binomial)

fit <- madlib.glm(rings < 10 ~ arr - arr[1:2], data = array.data, family = binomial)

fit <- madlib.glm(rings < 10 ~ arr[1:7] + sex | id %% 3, data = array.data, family = 'binomial')

fit <- madlib.glm(rings < 10 ~ arr - arr[8] + sex | id %% 3, data = array.data, family = 'binomial')

## 4th example
## Step-wise feature selection
start <- madlib.glm(rings < 10 ~ . - id - sex, data = source_data, family = "binomial")
## step(start)

## ------------------------------------------------------------
## Examples for using GLM model

fit <- madlib.glm(rings < 10 ~ . - id - sex, data = source_data, family = binomial(probit),
                  control = list(max.iter = 10))

fit <- madlib.glm(rings ~ . - id | sex, data = source_data, family = poisson(log),
                  control = list(max.iter = 10))

fit <- madlib.glm(rings ~ . - id, data = source_data, family = Gamma(inverse),
                  control = list(max.iter = 10))

db.disconnect(cid, verbose = FALSE)
}
}

% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{madlib}
\keyword{stats}
