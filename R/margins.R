## Implement marginal effects

margins <- function (model, vars = ~., at.mean = FALSE,
                     factor.continuous = FALSE, na.action = NULL,
                     ...)
    UseMethod("margins", model)

## ----------------------------------------------------------------------

.prepare.ind.vars <- function(ind.vars)
{
    vars <- gsub("::[\\w\\s]+", "", ind.vars, perl = T)
    vars <- gsub("\"", "`", vars)
    vars <- gsub("\\(`([^\\[\\]]*)`\\)\\[(\\d+)\\]", "`\\1[\\2]`", vars)
    vars <- gsub("\\s", "", vars)
    vars <- .reverse.consistent.func(vars)
    vars
}

## ----------------------------------------------------------------------

.parse.margins.vars <- function(model, vars)
{
    coef <- model$coef
    data <- model$data
    model.vars <- .prepare.ind.vars(model$ind.vars)
    fake.data <- structure(vector("list", length(model.vars)),
                           names = gsub("`", "", model.vars),
                           class = "data.frame")
    f.terms <- terms(vars, data = fake.data)
    f.vars <- gsub("\\s", "", attr(f.terms, "term.labels"))
    expand.vars <- character(0)
    for (i in seq_len(length(f.vars))) {
        if (grepl("^[^\\[\\]]*\\[[^\\[\\]]*\\]$", f.vars[i], perl = T)) {
            var <- gsub("`", "", f.vars[i])
            x.str <- gsub("([^\\[\\]]*)\\[[^\\[\\]]*\\]", "\\1", var,
                          perl = TRUE)
            idx <- gsub("[^\\[\\]]*\\[([^\\[\\]]*)\\]", "\\1", var,
                        perl = TRUE)
            idx <- eval(parse(text = idx))
            expand.vars <- c(expand.vars, paste("`", x.str, "[", idx, "]`", sep = ""))
        } else {
            expand.vars <- c(expand.vars, f.vars[i])
        }
    }
    if (any(! (gsub("`", "", expand.vars) %in% c(gsub("`", "", model.vars),
                                            names(.expand.array(data))))))
        stop("All the variables must be in the independent variables ",
             " or the table column names!")
    model.vars <- lapply(model.vars, function(x)
                         eval(parse(text=paste("quote(", x, ")", sep = ""))))
    names(model.vars) <- paste("var", seq_len(length(model.vars)), sep = "")
    return (list(vars = expand.vars, model.vars = model.vars))
}

## ----------------------------------------------------------------------

margins.lm.madlib <- function(model, vars = ~., newdata = model$data,
                              at.mean = FALSE, factor.continuous = FALSE,
                              na.action = NULL, ...)
{
    newdata <- .handle.dummy(newdata, model)
    f <- .parse.margins.vars(model, vars)
    n <- length(model$coef)
    if (model$has.intercept)
        P <- "b1 + " %+% paste("b", 2:n, "*var", (2:n)-1, collapse="+",
                               sep = "")
    else
        P <- paste("b", 1:n, "*var", 1:n, collapse="+", sep = "")
    if (at.mean) {
        avgs <- lk(mean(newdata))
        avgs <- .expand.avgs(avgs)
        names(avgs) <- gsub("_avg$", "", names(avgs))
    } else
        avgs <- NULL
    res <- .margins.lin(P, model, model$coef, newdata, f$vars, f$model.vars,
                        at.mean, factor.continuous, avgs = avgs)
    mar <- res$mar
    se <- sqrt(diag(res$se))
    t <- mar / se
    p <- 2 * (1 - pt(abs(t), nrow(newdata) - n))
    res <- data.frame(cbind(Estimate = mar, `Std. Error` = se, `t value` = t,
                            `Pr(>|t|)` = p), row.names = gsub("`", "", f$vars),
                      check.names = FALSE)
    class(res) <- c("margins", "data.frame")
    res
}

## ----------------------------------------------------------------------

margins.lm.madlib.grps <- function(model, vars = ~.,
                                   newdata = lapply(model, function(x) x$data),
                                   at.mean = FALSE, factor.continuous = FALSE,
                                   na.action = NULL, ...)
{
    if (length(newdata) == 1) 
        lapply(seq_len(length(model)), function (i)
               margins(model[[i]], vars, newdata, at.mean,
                       factor.continuous, na.action, ...))
    else if (length(newdata) == length(model))
        lapply(seq_len(length(model)), function (i)
               margins(model[[i]], vars, newdata[[i]], at.mean,
                       factor.continuous, na.action, ...))
    else
        stop("The number db.obj objects in newdata must be 1 or equal to length of model!")
}

## ----------------------------------------------------------------------

margins.logregr.madlib <- function(model, vars = ~., newdata = model$data,
                                   at.mean = FALSE, factor.continuous = FALSE,
                                   na.action = NULL, ...)
{
    newdata <- .handle.dummy(newdata, model)
    f <- .parse.margins.vars(model, vars)
    n <- length(model$coef)
    if (model$has.intercept)
        P <- "b1 +" %+% paste("b", 2:n, "*var", (2:n)-1,
                                  collapse="+", sep = "")
    else
        P <- paste("b", 1:n, "*var", 1:n, collapse="+", sep = "")
    sigma <- paste("1/(1+exp(-(", P, ")))")
    sigma.name <- gsub("__", "", .unique.string())

    coefs <- as.list(model$coef)
    n <- length(coefs)
    m <- length(vars)
    names(coefs) <- paste("b", seq_len(n), sep = "")
    avgs <- NULL
    cmd <- paste("substitute(", sigma, ", c(f$model.vars, coefs))", sep = "")
    expr <- gsub("\\s", "", paste(deparse(eval(parse(text = cmd))), collapse = ""))

    if (at.mean) {
        avgs <- lk(mean(newdata))
        avgs <- .expand.avgs(avgs)
        names(avgs) <- gsub("_avg$", "", names(avgs))
        expr <- gsub("\\s", "",
                     paste(deparse(eval(parse(text = paste("substitute(",
                                              expr, ", avgs)", sep = "")))),
                           collapse = ""))
        avgs[[sigma.name]] <- eval(parse(text = expr))
    } else {
        newdata[[sigma.name]] <- .with.data(newdata, expr)
        newdata <- as.db.Rview(newdata)
    }

    res <- .margins.log(P, model, model$coef, newdata, f$vars, f$model.vars,
                        sigma.name, at.mean, factor.continuous, avgs = avgs)

    mar <- res$mar
    se <- sqrt(diag(res$se))
    z <- mar / se
    p <- 2 * (1 - pnorm(abs(z)))
    res <- data.frame(cbind(Estimate = mar, `Std. Error` = se, `z value` = z,
                            `Pr(>|z|)` = p), row.names = gsub("`", "", f$vars),
                      check.names = FALSE)
    class(res) <- c("margins", "data.frame")
    res
}

## ----------------------------------------------------------------------

print.margins <- function(x,
                          digits = max(3L, getOption("digits") - 3L),
                          ...)
{
    printCoefmat(x, digits = digits, signif.stars = TRUE)
}

## ----------------------------------------------------------------------

margins.logregr.madlib.grps <- function(model, vars = ~.,
                                        newdata = lapply(model, function(x) x$data),
                                        at.mean = FALSE, factor.continuous = FALSE,
                                        na.action = NULL, ...)
{
    if (length(newdata) == 1) 
        lapply(seq_len(length(model)), function (i)
               margins(model[[i]], vars, newdata, at.mean,
                       factor.continuous, na.action, ...))
    else if (length(newdata) == length(model))
        lapply(seq_len(length(model)), function (i)
               margins(model[[i]], vars, newdata[[i]], at.mean,
                       factor.continuous, na.action, ...))
    else
        stop("The number db.obj objects in newdata must be 1 or equal to length of model!")
}
## ----------------------------------------------------------------------

.with.data <- function(data, expr.str, type = "double precision",
                       is.agg = FALSE)
{
    nm <- names(data)[1]
    x <- data[[nm]]
    x@.expr <- .consistent.func(expr.str)
    x@.col.name <- .unique.string()
    x@.col.data_type <- type
    x@.is.agg <- is.agg
    x@.content <- gsub("^select (.*) from",
                       paste("select ", x@.expr, " as ", x@.col.name, " from",
                             sep = ""),
                       x@.content)
    x
}

## ----------------------------------------------------------------------

## expand x into x[1], x[2], ...
.expand.avgs <- function(avgs)
{
    n <- ncol(avgs)
    res <- avgs
    for (i in seq_len(n)) {
        if (is.array(avgs[,i])) {
            a <- as.list(avgs[,i])
            names(a) <- paste(names(avgs)[i], "[", seq_len(length(avgs[,i])),
                              "]", sep = "")
            res <- c(res, a)
        }
    }
    res
}

## ----------------------------------------------------------------------

## create a db.Rview object which contains the dummy variable
.handle.dummy <- function(data, model)
{
    l <- length(model$dummy)
    if (l != 0) {
        data <- .db.data.frame2db.Rquery(data)
        data@.col.name <- c(data@.col.name, model$dummy)
        data@.expr <- c(data@.expr, model$dummy.expr)
        data@.col.data_type <- c(data@.col.data_type,
                                 rep("double precision", l))
        data@.col.udt_name <- c(data@.col.udt_name, rep("float8", l))
        if (data@.source == data@.parent)
            tbl <- data@.parent
        else
            tbl <- "(" %+% data@.parent %+% ") s"
        where <- data@.where
        if (where != "") where.str <- paste(" where", where)
        else where.str <- ""
        sort <- data@.sort
        data@.content <- paste("select ", paste(data@.expr, " as \"",
                                                data@.col.name, "\"",
                                                sep = ""),
                               " from ", tbl, where.str, sort$str, sep = "")
        as.db.Rview(data)
    } else {
        if (is(data, "db.data.frame"))
            data
        else
            as.db.Rview(data)
    }
}

## ----------------------------------------------------------------------

## special margins for linear
.margins.lin <- function(P, model, coef, data, vars, model.vars,
                         at.mean = FALSE, factor.continuous = FALSE,
                         avgs = NULL)
{
    coefs <- as.list(coef)
    n <- length(coefs)
    m <- length(vars)
    names(coefs) <- paste("b", seq_len(n), sep = "")
    if (at.mean) {
        mar <- sapply(
            vars,
            function(i) {
                eval(parse(text = "with(avgs," %+%
                           .sub.coefs(.dx(P, i, model.vars), coefs) %+% ")"))
            })
        se <- array(0, dim = c(m,n))
        for (i in seq_len(m)) {
            s <- .dx(P, vars[i], model.vars)
            se[i,] <- sapply(
                seq_len(n),
                function(j) {
                    eval(parse(
                        text = paste("with(avgs,",
                        .sub.coefs(.parse.deriv(s, "b"%+%j), coefs),
                        ")", sep = "")))
                })
        }
    } else {
        mar <- sapply(
            vars,
            function(i) {
                .with.data(
                    data,
                    paste("avg(", .sub.coefs(.dx(P, i, model.vars), coefs),
                          ")", sep = ""))
            })
        for (i in seq_len(m)) {
            s <- .dx(P, vars[i], model.vars)
            e <- sapply(
                seq_len(n),
                function(j) {
                    .with.data(data, paste(
                        "avg(", .sub.coefs(.parse.deriv(s, "b"%+%j), coefs),
                        ")", sep = ""), is.agg = TRUE)
                })
            if (i == 1)
                se <- e
            else
                se <- c(se, e)
        }
        mar.se <- c(mar, se)
        if (any(sapply(mar.se, function(s) is(s, "db.obj")))) {
            mar.se <- .combine.list(mar.se)
            mar.se <- unlist(lk(mar.se, -1))
        }
        mar <- mar.se[seq_len(m)]
        se <- t(array(mar.se[-seq_len(m)], dim = c(n,m)))
    }
    names(mar) <- gsub("`", "", vars)
    v <- vcov(model)
    se <- se %*% v %*% t(se)
    return(list(mar=mar, se=se))
}

## ----------------------------------------------------------------------

.margins.log <- function(P, model, coef, data, vars, model.vars, sigma,
                         at.mean = FALSE, factor.continuous = FALSE,
                         avgs = NULL)
{
    conn.id <- conn.id(data)
    coefs <- as.list(coef)
    n <- length(coefs)
    m <- length(vars)
    names(coefs) <- paste("b", seq_len(n), sep = "")
    if (at.mean) {
        mar <- sapply(
            vars,
            function(i) {
                eval(parse(text = "with(avgs," %+%
                           .sub.coefs(.dx(P, i, model.vars), coefs) %+% ")"))
            })
        mar <- mar * avgs[[sigma]] * (1 - avgs[[sigma]])
        
        se <- array(0, dim = c(m,n))
        for (i in seq_len(m)) {
            s <- .dx(P, vars[i], model.vars)
            se[i,] <- sapply(
                seq_len(n),
                function(j) {
                    (eval(parse(
                        text = paste("with(avgs,",
                        .sub.coefs(.parse.deriv(s, "b"%+%j), coefs),
                        ")", sep = "")))
                     * avgs[[sigma]] * (1 - avgs[[sigma]]) +
                     eval(parse(
                         text = paste("with(avgs,",
                         .sub.coefs(paste("(", s, ")*(",
                                          .dj(P, j, model.vars), ")",
                                          sep = ""), coefs), ")", sep = "")))
                    * avgs[[sigma]] * (1 - avgs[[sigma]]) * (1 - 2*avgs[[sigma]]))
                })
        }
    } else {
        madlib <- schema.madlib(conn.id(data))
        mar <- paste("array[", paste(sapply(
            vars,
            function(i) {
                .sub.coefs(.dx(P, i, model.vars), coefs)
            }), collapse = ", "), "]::double precision[]", sep = "")
        mar <- paste(madlib, ".avg(", madlib, ".array_scalar_mult(", mar,
                     ",", sigma, "*(1 - ", sigma, ")::double precision))",
                     sep = "")

        se1 <- paste(sapply(
            vars,
            function(i) {
                s <- .dx(P, i, model.vars)
                paste(sapply(
                    seq_len(n),
                    function(j) {
                        .sub.coefs(.parse.deriv(s, "b"%+%j), coefs)
                    }), collapse = ", ")
            }), collapse = ", ")

        se2 <- paste(sapply(
            vars,
            function(i) {
                s <- .dx(P, i, model.vars)
                paste(sapply(
                    seq_len(n),
                    function(j) {
                        .sub.coefs(paste("(", s, ")*(", .dj(P, j, model.vars),
                                         ")", sep = ""), coefs)
                    }), collapse = ", ")
            }), collapse = ", ")

        se1 <- paste(madlib, ".avg(", madlib, ".array_scalar_mult(array[",
                     se1, "]::double precision[],", sigma,
                     "*(1 - ", sigma, ")::double precision))", sep = "")
        se2 <- paste(madlib, ".avg(", madlib, ".array_scalar_mult(array[",
                     se2, "]::double precision[],", sigma,
                     "*(1-", sigma, ")*(1-2*", sigma,
                     ")::double precision))", sep = "")

        mar.se <- paste("select ", mar, " as mar, ", se1, " as se1, ",
                        se2, " as se2 from (", data@.parent, ") s",
                        sep = "")

        mar.se <- db.q(mar.se, conn.id=conn.id, verbose = FALSE)
        mar <- as.vector(arraydb.to.arrayr(mar.se$mar))
        se <- t(array(as.vector(arraydb.to.arrayr(mar.se$se1) +
                                arraydb.to.arrayr(mar.se$se2)), dim = c(n,m)))
    }
    names(mar) <- gsub("`", "", vars)
    v <- vcov(model)
    se <- se %*% v %*% t(se)
    return(list(mar=mar, se=se))
}

## ----------------------------------------------------------------------

.dx <- function(P, x, model.vars)
{
    mv <- gsub("\\s", "",
               gsub("`", "", sapply(model.vars, function(s)
                                    paste(.strip(deparse(s), "\\n"),
                                          collapse=""))))
    xv <- gsub("`", "", x)
    if (xv %in% mv) {
        i <- which(mv == xv)
        s <- .parse.deriv(P, "var" %+% i)
        s <- paste(deparse(eval(parse(text = paste("substitute(", s,
                                      ", model.vars)")))), collapse = "")
        s <- gsub("\\n", "", s)
    } else {
        P <- paste(deparse(eval(parse(text = paste("substitute(", P,
                                      ", model.vars)", sep = "")))),
                   collapse = "")
        P <- gsub("\\n", "", P)
        x <- paste(deparse(eval(parse(text = paste("quote(", x, ")")))),
                   collapse = "")
        x <- gsub("\\n", "", x)
        s <- .parse.deriv(P, x)
    }
    s
}

## ----------------------------------------------------------------------

.dj <- function(P, j, model.vars)
{
    P <- paste(deparse(eval(parse(text = paste("substitute(", P,
                                  ", model.vars)", sep = "")))),
               collapse = "")
    P <- gsub("\\n", "", P)
    .parse.deriv(P, "b"%+%j)
}

## ----------------------------------------------------------------------

.sub.coefs <- function(s, coefs)
{
    w <- eval(parse(text = paste("substitute(", s, ", coefs)", sep = "")))
    w <- gsub("`", "", as.character(enquote(w))[2])
    w
}