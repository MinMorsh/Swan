function dom = DP(A,B)
    s.operation = @(xV) evaluate(A,B,xV);
    if isa(A,'DomainFunction')
        s.mesh = A.mesh;
    else
        s.mesh = B.mesh;
    end
    dom         = DomainFunction(s);
end

function aDb = evaluate(a,b,xV)
    aEval = a.evaluate(xV);
    bEval = b.evaluate(xV);
    aEval = pagetranspose(aEval);
    aDb = pagemtimes(aEval,bEval);
    aDb = squeezeParticular(aDb,1);
end