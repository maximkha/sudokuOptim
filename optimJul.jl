using SparseArrays
using Optim
using LinearAlgebra

BOARD_SIZE = 4 #this is also maxcell
CHUNK_SIZE = 2

MIN_CELL = 1

EPSILON = .01

# sparse([1,2], [1,2], [1,0])#
#y,x
sparseBoard = sparse([1,1,4,4], [1,2,3,4], [1,2,3,1])
#sparseBoard = sparse([1,1,1,1,2,2,2,3,3,3,3,3,4,4,4,4,5,5,5,5,6,6,6,6,7,7,7,7,7,8,8,8,9,9,9,9,], [2,7,8,9,3,5,9,1,2,4,5,8,1,4,5,6,2,4,6,8,4,5,6,9,2,5,6,8,9,1,5,7,1,2,3,8,], [8,6,3,1,5,3,8,3,9,4,1,2,8,3,7,5,5,2,1,8,8,6,4,3,3,2,7,9,4,6,4,8,2,4,1,6,])

# obviously not the best solution to the problem
# also kind of a hack as I introduce nuisance terms
# however, this still generates the optimal expression, which will be evaluated many times by the optimizer compared to this function which is evaluated once.
function generateOptimExpr(boardSize, chunkSize)
    optimExpr = :(0)

    fac = factorial(boardSize)
    csum = sum(1:boardSize)

    # optimExpr = :(($optimExpr)+((V[($linearIndex)]-($floatVal))^2))
    for x in 1:boardSize
        for y in 1:boardSize
            if sparseBoard[y,x] != 0
                linearIndex = boardSize*(y-1) + x
                floatVal = convert(Float64,sparseBoard[y,x])
                optimExpr = :(($optimExpr)+((V[($linearIndex)]-($floatVal))^2))
            end
        end
    end

    # generate the column product rules
    # aka the product of all the column numbers should be equal to the board size factorial
    for x in 1:boardSize
        colProd = :(1)
        colSum = :(0)
        for y in 1:boardSize
            linearIndex = boardSize*(y-1) + x
            if sparseBoard[y,x] != 0
                floatVal = convert(Float64,sparseBoard[y,x])
                colProd = :($colProd*$floatVal)
                colSum = :($colSum+$floatVal)
            else
                colProd = :($colProd*V[$linearIndex])
                colSum = :($colSum+V[$linearIndex])
            end
            #colProd = :($colProd*V[$linearIndex])
        end
        optimExpr = :($optimExpr+((($colProd)-$fac)^2))

        for sumPow in 1:boardSize
            optimExpr = :(($optimExpr)+(((($colSum)^$sumPow)-$(csum^sumPow))^2))
        end
    end

    #generate the row product rules
    for y in 1:boardSize
        rowProd = :(1)
        rowSum = :(0)
        for x in 1:boardSize
            linearIndex = boardSize*(y-1) + x
            if sparseBoard[y,x] != 0
                floatVal = convert(Float64,sparseBoard[y,x])
                rowProd = :($rowProd*$floatVal)
                rowSum = :($rowSum+$floatVal)
            else
                rowProd = :($rowProd*V[$linearIndex])
                rowSum = :($rowSum+V[$linearIndex])
            end
            #rowProd = :($rowProd*V[$linearIndex])
        end
        optimExpr = :(($optimExpr)+((($rowProd)-$fac)^2))
        #optimExpr = :(($optimExpr)+((($rowSum)-$csum)^2))
        for sumPow in 1:boardSize
            optimExpr = :(($optimExpr)+(((($rowSum)^$sumPow)-$(csum^sumPow))^2))
        end
    end

    #generate the square cell product rules
    #really bad convolution like operator
    for yAnchor in 1:chunkSize:boardSize
        for xAnchor in 1:chunkSize:boardSize
            cellProduct = :(1)
            cellSum = :(0)
            for xOffset in 0:(chunkSize - 1)
                for yOffset in 0:(chunkSize - 1)
                    x = xAnchor + xOffset
                    y = yAnchor + yOffset
                    linearIndex = boardSize*(y-1) + x

                    if sparseBoard[y,x] != 0
                        floatVal = convert(Float64,sparseBoard[y,x])
                        cellProduct = :($cellProduct*$floatVal)
                        cellSum = :($cellSum+$floatVal)
                    else
                        cellProduct = :($cellProduct*V[$linearIndex])
                        cellSum = :($cellSum+V[$linearIndex])
                    end
                    
                    #cellProduct = :($cellProduct*V[$linearIndex])
                end
            end
            optimExpr = :(($optimExpr)+(($cellProduct-($fac))^2))
            #optimExpr = :(($optimExpr)+((($cellSum)-$csum)^2))
        
            for sumPow in 1:boardSize
                optimExpr = :(($optimExpr)+(((($cellSum)^$sumPow)-$(csum^sumPow))^2))
            end
        end
    end

    # for i in 1:boardSize^2
    #     optimExpr = :(($optimExpr)+mod(V[$i],1))
    # end

    optimExpr
end

function linearize2dSquare(mat2d, nZero)
    s = size(mat2d)[1]
    flat = zeros(Float64,s*s)
    for y in 1:s
        for x in 1:s
            linearIndex = s * (y - 1) + x
            iVal = mat2d[y,x]
            if iVal == 0
                iVal = nZero
            end
            floatVal = convert(Float64, iVal)
            flat[linearIndex] = floatVal
        end
    end
    flat
end

# NOTE: this is created without knowledge of the solution!
optExpression = generateOptimExpr(BOARD_SIZE, CHUNK_SIZE) #create a mathematical expression that represents the loss given an linearized sudoku board
f = eval(:(V->$optExpression)) #create lambda that returns loss given a set of guesses
initGuesses = linearize2dSquare(sparseBoard, BOARD_SIZE/2) #the initial guesses are the given clues + a default value for each cell, in this case (the middle board value)
# generate min and max bounds on values
minBounds = ones(BOARD_SIZE^2) .- EPSILON
maxBounds = ones(BOARD_SIZE^2) * (BOARD_SIZE + EPSILON)

# initGuesses = big.(initGuesses)
# minBounds = big.(minBounds)
# maxBounds = big.(maxBounds)

# f = v->(v[1]+v[2])^2
# initGuesses = [1.;1.]
# minBounds = [-1.;-1.]
# maxBounds = [1.;1.]

println(optExpression)
println(view(sparseBoard, :, :))

println("1")

inner_optimizer = ConjugateGradient()
#results = optimize(f, minBounds, maxBounds, initGuesses, Fminbox(inner_optimizer), Optim.Options(show_trace=true, iterations=5000);)
od = OnceDifferentiable(f, initGuesses; autodiff = :forward)
println("2")
results = optimize(od, minBounds, maxBounds, initGuesses, Fminbox(inner_optimizer), Optim.Options(allow_f_increases=true, show_trace=true, show_every=100);)
println(results)
println(initGuesses)
println(Optim.minimizer(results))
println(round.(Int64,Optim.minimizer(results)))
#println(linearize2dSquare([1 2 4 3; 4 3 1 2; 3 1 2 4; 2 4 3 1], 0))
println(Optim.minimum(results))

#println(f(linearize2dSquare([1 2 4 3; 4 3 1 2; 3 1 2 4; 2 4 3 1], 0)))
#println(f(linearize2dSquare([1 2;2 1], 0)))
# function generateSum(n)
#     se = :(0)
#     for x in 1:n
#         se = :(($se)+$x)
#     end
#     se
# end

# Optim.optimize(OnceDifferentiable(f, [1.0,2.0], autodiff=:forward), 
#     [1.0,2.0], [0.0,-Inf], [Inf,Inf], 
#     Fminbox{BFGS}(), 
#     optimizer_o=Optim.Options(iterations=1000))