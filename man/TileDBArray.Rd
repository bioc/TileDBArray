% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/TileDBArray.R
\name{TileDBArray}
\alias{TileDBArray}
\alias{TileDBArraySeed}
\alias{TileDBArraySeed-class}
\alias{TileDBArray-class}
\alias{TileDBMatrix}
\alias{TileDBMatrix-class}
\alias{show,TileDBArraySeed-method}
\alias{is_sparse,TileDBArraySeed-method}
\alias{type,TileDBArraySeed-method}
\alias{extract_array,TileDBArraySeed-method}
\alias{extract_sparse_array,TileDBArraySeed-method}
\alias{DelayedArray,TileDBArraySeed-method}
\alias{path,TileDBArraySeed-method}
\alias{chunkdim,TileDBArraySeed-method}
\alias{matrixClass,TileDBArray-method}
\title{Delayed TileDB arrays}
\description{
The TileDBArray class provides a \linkS4class{DelayedArray} backend for TileDB arrays (sparse and dense).
}
\section{Constructing a TileDBArray}{

\code{TileDBArray(x, attr)} returns a TileDBArray object given:
\itemize{
\item \code{x}, a string containing a URI to a TileDB backend, most typically a path to a directory.
\item \code{attr}, a string specifying the attribute to represent in the array.
Defaults to the first attribute.
}
Alternatively, \code{x} can be a TileDBArraySeed object, in which case \code{attr} is ignored.

\code{TileDBArraySeed(x, attr)} returns a TileDBArraySeed
with the same arguments as described for \code{TileDBArray}.
If \code{x} is already a TileDBArraySeed, it is returned
directly without further modification.

\code{\link{DelayedArray}(x)} returns a TileDBArray object
given \code{x}, a TileDBArraySeed.

In all cases, two-dimensional arrays will automatically generate a TileDBMatrix,
a subclass of the TileDBArray.
}

\section{Available operations}{

\code{\link{extract_array}(x, index)} will return an ordinary array containing values from the TileDBArraySeed \code{x},
subsetted to the indices specified in \code{index}. 
The latter should be a list of length equal to the number of dimensions in \code{x},
where each entry is an integer vector or \code{NULL} (in which case the entirety of the dimension is used).

\code{\link{extract_sparse_array}(x, index)} will return a \linkS4class{COO_SparseArray}
representing the subset of \code{x} corresponding to the indices in \code{index}.
The latter should be a list of the same structure as described for \code{extract_array}.

\code{\link{type}(x)} will return a string containing the type of the TileDBArraySeed object \code{x}.
Currently, only \code{"integer"}, \code{"logical"} and \code{"double"}-precision is supported.

\code{\link{is_sparse}(x)} will return a logical scalar indicating 
whether the TileDBArraySeed \code{x} uses a sparse format in the TileDB backend.

\code{\link{path}(x)} will return a string containing the path to the TileDB backend directory.

\code{\link{chunkdim}(x)} will return an integer vector containing the tile extent in each dimension.
This will be used as the chunk dimensions in methods like \code{\link{chunkGrid}}.

All of the operations described above are also equally applicable to TileDBArray objects, 
as their methods simply delegate to those of the TileDBArraySeed.

All operations supported by \linkS4class{DelayedArray} objects are 
also available for TileDBArray objects.
}

\examples{
data <- matrix(rpois(10000, 5), nrow=100, ncol=100)
B <- as(data, "TileDBArray")
B

# Apply typical DelayedArray operations:
as.matrix(B[1:10,1:10])
B \%*\% runif(ncol(B))

# This also works for sparse arrays:
sdata <- Matrix::rsparsematrix(nrow=100, ncol=100, density=0.1)
C <- as(sdata, "TileDBArray")
C

}
\author{
Aaron Lun
}
