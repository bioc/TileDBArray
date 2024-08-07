#' Delayed TileDB arrays
#'
#' The TileDBArray class provides a \linkS4class{DelayedArray} backend for TileDB arrays (sparse and dense).
#'
#' @section Constructing a TileDBArray:
#' \code{TileDBArray(x, attr)} returns a TileDBArray object given:
#' \itemize{
#' \item \code{x}, a string containing a URI to a TileDB backend, most typically a path to a directory.
#' \item \code{attr}, a string specifying the attribute to represent in the array.
#' Defaults to the first attribute.
#' }
#' Alternatively, \code{x} can be a TileDBArraySeed object, in which case \code{attr} is ignored.
#'
#' \code{TileDBArraySeed(x, attr)} returns a TileDBArraySeed
#' with the same arguments as described for \code{TileDBArray}.
#' If \code{x} is already a TileDBArraySeed, it is returned
#' directly without further modification.
#'
#' \code{\link{DelayedArray}(x)} returns a TileDBArray object
#' given \code{x}, a TileDBArraySeed.
#'
#' In all cases, two-dimensional arrays will automatically generate a TileDBMatrix,
#' a subclass of the TileDBArray.
#'
#' @section Available operations:
#' \code{\link{extract_array}(x, index)} will return an ordinary array containing values from the TileDBArraySeed \code{x},
#' subsetted to the indices specified in \code{index}. 
#' The latter should be a list of length equal to the number of dimensions in \code{x},
#' where each entry is an integer vector or \code{NULL} (in which case the entirety of the dimension is used).
#'
#' \code{\link{extract_sparse_array}(x, index)} will return a \linkS4class{COO_SparseArray}
#' representing the subset of \code{x} corresponding to the indices in \code{index}.
#' The latter should be a list of the same structure as described for \code{extract_array}.
#'
#' \code{\link{type}(x)} will return a string containing the type of the TileDBArraySeed object \code{x}.
#' Currently, only \code{"integer"}, \code{"logical"} and \code{"double"}-precision is supported.
#'
#' \code{\link{is_sparse}(x)} will return a logical scalar indicating 
#' whether the TileDBArraySeed \code{x} uses a sparse format in the TileDB backend.
#'
#' \code{\link{path}(x)} will return a string containing the path to the TileDB backend directory.
#'
#' \code{\link{chunkdim}(x)} will return an integer vector containing the tile extent in each dimension.
#' This will be used as the chunk dimensions in methods like \code{\link{chunkGrid}}.
#'
#' All of the operations described above are also equally applicable to TileDBArray objects, 
#' as their methods simply delegate to those of the TileDBArraySeed.
#'
#' All operations supported by \linkS4class{DelayedArray} objects are 
#' also available for TileDBArray objects.
#' 
#' @aliases
#' TileDBArraySeed
#' TileDBArraySeed-class
#' TileDBArray
#' TileDBArray-class
#' TileDBMatrix
#' TileDBMatrix-class
#'
#' show,TileDBArraySeed-method
#' is_sparse,TileDBArraySeed-method
#' type,TileDBArraySeed-method
#' extract_array,TileDBArraySeed-method
#' extract_sparse_array,TileDBArraySeed-method
#' DelayedArray,TileDBArraySeed-method
#' path,TileDBArraySeed-method
#' chunkdim,TileDBArraySeed-method
#' matrixClass,TileDBArray-method
#'
#' @author Aaron Lun
#' 
#' @examples
#' data <- matrix(rpois(10000, 5), nrow=100, ncol=100)
#' B <- as(data, "TileDBArray")
#' B
#'
#' # Apply typical DelayedArray operations:
#' as.matrix(B[1:10,1:10])
#' B %*% runif(ncol(B))
#'
#' # This also works for sparse arrays:
#' sdata <- Matrix::rsparsematrix(nrow=100, ncol=100, density=0.1)
#' C <- as(sdata, "TileDBArray")
#' C
#'
#' @name TileDBArray
NULL

#' @export
TileDBArraySeed <- function(x, attr) { 
    if (is(x, "TileDBArraySeed")) {
        return(x)
    }

    obj <- tiledb_array(x)
    on.exit(tiledb_array_close(obj))

    s <- schema(obj)
    d <- dim(domain(s))

    a <- attrs(s)
    if (missing(attr)) {
        attr <- names(a)[1]
    } else if (!attr %in% names(a)) {
        stop("'attr' not in the TileDB attributes")
    }
    
    my.type <- tiledb:::tiledb_datatype_R_type(datatype(a[[attr]]))
    if (! my.type %in% c("logical", "double", "integer", "character")) {
        stop("'attr' refers to an unsupported type")
    }
    
    meta <- .get_metadata(x, sparse=is.sparse(s))
    if (my.type=="integer" && identical(meta$type, "logical")) {
        my.type <- meta$type
    }

    dimnames <- vector("list", length(d))
    if (!is.null(meta$dimnames)) {
        dimnames <- meta$dimnames
    }

    new("TileDBArraySeed", dim=d, dimnames=dimnames, path=x, 
        sparse=is.sparse(s), attr=attr, type=my.type, extent=meta$extent)
}

.get_metadata <- function(path, sparse) {
    obj <- tiledb_array(path)
    on.exit(tiledb_array_close(obj), add=TRUE)
    obj <- tiledb_array_open(obj, "READ")

    type <- tiledb_get_metadata(obj, "type")

    dimnames <- tiledb_get_metadata(obj, "dimnames")
    if (!is.null(dimnames)) {
        dimnames <- .unpack_dimnames(dimnames)
    }

    D <- dimensions(schema(obj))
    extent <- vapply(D, tile, 0L)

    list(type=type, dimnames=dimnames, extent=extent)
}

#' @importFrom S4Vectors setValidity2
setValidity2("TileDBArraySeed", function(object) {
    msg <- .common_checks(object)

    d <- dim(object)
    dn <- dimnames(object)
    if (length(dn)!=length(d)) {
        msg <- c(msg, "'dimnames' must the same length as 'dim'")
    }
    if (!all(d==lengths(dn) | vapply(dn, is.null, FALSE))) {
        msg <- c(msg, "each 'dimnames' must be NULL or the same length as the corresponding dimension")
    }

    if (length(msg)) {
        msg
    } else {
        TRUE
    }
})

#' @export
#' @importFrom methods show
setMethod("show", "TileDBArraySeed", function(object) {
    cat(sprintf("%i x %i TileDBArraySeed object\n", nrow(object), ncol(object)))
})

#' @export
setMethod("is_sparse", "TileDBArraySeed", function(x) x@sparse)

#' @export
setMethod("type", "TileDBArraySeed", function(x) x@type)

#' @export
setMethod("chunkdim", "TileDBArraySeed", function(x) {
    x@extent
})

#' @export
#' @importFrom DelayedArray path
setMethod("path", "TileDBArraySeed", function(object, ...) {
    object@path
})

#' @export
setMethod("extract_array", "TileDBArraySeed", function(x, index) {
    fill <- switch(type(x), double=0, integer=0L, logical=FALSE)
    d2 <- .get_block_dims(x, index)
    output <- array(fill, dim=d2)

    # Hack to overcome zero-length indices that cause tiledb to throw.
    if (any(d2==0L)) {
        return(output)
    }

    obj <- tiledb_array(path(x), attrs=x@attr, query_type="READ", as.data.frame=TRUE)
    on.exit(tiledb_array_close(obj))

    df <- .extract_values(obj, index)
    output[df$indices] <- as(df$values, type(x))
    output
})

.get_block_dims <- function(x, index) {
    d <- dim(x)
    for (i in seq_along(index)) {
        if (!is.null(index[[i]])) {
            d[i] <- length(index[[i]])
        }
    }
    d
}

#' @export
#' @importFrom SparseArray extract_sparse_array COO_SparseArray
setMethod("extract_sparse_array", "TileDBArraySeed", function(x, index) {
    d2 <- .get_block_dims(x, index)
    if (any(d2==0L)) {
        return(COO_SparseArray(d2, nzdata=vector(type(x))))
    }

    obj <- tiledb_array(path(x), attrs=x@attr, query_type="READ")
    on.exit(tiledb_array_close(obj))

    df <- .extract_values(obj, index)
    COO_SparseArray(d2, nzcoo=df$indices, nzdata=as(df$values, type(x)))
})

#' @export
TileDBArray <- function(x, ...) {
    DelayedArray(TileDBArraySeed(x, ...))
}

#' @export
setMethod("DelayedArray", "TileDBArraySeed",
    function(seed) new_DelayedArray(seed, Class="TileDBArray")
)

#' @export
setMethod("matrixClass", "TileDBArray", function(x) "TileDBMatrix")

.format_indices <- function(index) {
    ndim <- length(index)
    contiguous <- remapping <- vector("list", ndim)

    for (i in seq_len(ndim)) {
        cur.index <- index[[i]]

        if (!is.null(cur.index)) {
            o <- order(cur.index)
            runs <- rle(cur.index[o])

            rv <- runs$value
            remapping[[i]] <- list(
                ref.value=rv,
                ref.length=runs$length,
                requested=o
            )
    
            is.not.contig <- which(diff(rv)!=1L)
            contiguous[[i]] <- cbind(
                rv[c(1L, is.not.contig + 1L)],
                rv[c(is.not.contig, length(rv))]
            )
        }
    }

    list(contiguous=contiguous, remapping=remapping)
}

.extract_values <- function(obj, indices) {
    index.info <- .format_indices(indices)
    selected_ranges(obj) <- index.info$contiguous
    extracted <- obj[]

    # Resolves a 1-to-many mapping between the extracted and requested indices.
    ndim <- length(indices)
    output <- remap_indices(as.list(extracted[seq_len(ndim)]), index.info$remapping)

    list(
        indices=output$indices,
        values=rep.int(extracted[[ndim + 1L]], output$expand)
    )
}
