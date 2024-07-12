classdef ElasticProblem < handle
    
    properties (Access = public)
        uFun
        strainFun
        stressFun
        forces
    end

    properties (Access = private)
        quadrature
        boundaryConditions, BCApplier

        stiffness
        solver, solverType, solverMode, solverCase
        scale
        
        strain, stress
    end

    properties (Access = protected)
        mesh 
        material  
        displacementFun
    end

    methods (Access = public)

        function obj = ElasticProblem(cParams)
            obj.init(cParams);
            obj.createDisplacementFun();
            obj.createBCApplier();
            obj.createSolver();
        end

        function solve(obj)
            obj.computeStiffnessMatrix();
            obj.computeForces();
            obj.computeDisplacement();
            obj.computeStrain();
            obj.computeStress();
        end

        function updateMaterial(obj, mat)
            obj.material = mat;
        end
       
        function print(obj, filename, software)
            if nargin == 2; software = 'Paraview'; end
            [fun, funNames] = obj.getFunsToPlot();
            a.mesh     = obj.mesh;
            a.filename = filename;
            a.fun      = fun;
            a.funNames = funNames;
            a.type     = software;
            pst = FunctionPrinter.create(a);
            pst.print();
        end

        function [fun, funNames] = getFunsToPlot(obj)
            fun = {obj.uFun, obj.strainFun.project('P1',obj.mesh), ...
                obj.stressFun.project('P1',obj.mesh)};
            funNames = {'displacement', 'strain', 'stress'};
        end

        function Ju = computeInternalForces(obj)
            u = obj.uFun;
            quadOrder = 4;
            C = obj.material;
            sigma = DDP(C,SymGrad(u));
            test = LagrangianFunction.create(obj.mesh, u.ndimf, u.order);

            s.mesh = obj.mesh;
            s.quadratureOrder = quadOrder;
            s.type = 'ShapeSymmetricDerivative';
            RHS = RHSintegrator.create(s);
            Ju = RHS.compute(sigma,test);

%             Ju = reshape(Ju,[obj.mesh.ndim,obj.mesh.nnodes])';
% 
%             aa.fValues = Ju;
%             aa.mesh = obj.mesh;
%             aa.order = 'P1';
%             p1 = LagrangianFunction(aa)
%             p1.plot
        end
    end

    methods (Access = private)

        function init(obj, cParams)
            obj.mesh        = cParams.mesh;
            obj.material    = cParams.material;
            obj.scale       = cParams.scale;
            obj.mesh        = cParams.mesh;
            obj.solverType  = cParams.solverType;
            obj.solverMode  = cParams.solverMode;
            obj.boundaryConditions = cParams.boundaryConditions;
            if isfield(cParams,'solverCase')
                obj.solverCase  = cParams.solverCase;
            else
                obj.solverCase = 'DIRECT';
            end
        end

        function createDisplacementFun(obj)
            obj.displacementFun = LagrangianFunction.create(obj.mesh, obj.mesh.ndim, 'P1');
        end

        function dim = getFunDims(obj)
            d.ndimf  = obj.displacementFun.ndimf;
            d.nnodes = size(obj.displacementFun.fValues, 1);
            d.ndofs  = d.nnodes*d.ndimf;
            d.nnodeElem = obj.mesh.nnodeElem; % should come from interp..
            d.ndofsElem = d.nnodeElem*d.ndimf;
            dim = d;
        end

        function createBCApplier(obj)
            s.mesh = obj.mesh;
            s.boundaryConditions = obj.boundaryConditions;
            bc = BCApplier(s);
            obj.BCApplier = bc;
        end

        function createSolver(obj)
            s.type     = obj.solverCase;
            obj.solver = Solver.create(s);
        end

        function computeStiffnessMatrix(obj)
            ndimf = obj.displacementFun.ndimf;
            s.type     = 'ElasticStiffnessMatrix';
            s.mesh     = obj.mesh;
            s.test     = LagrangianFunction.create(obj.mesh,ndimf, 'P1');
            s.trial    = obj.displacementFun;
            s.material = obj.material;
            s.quadratureOrder = 2;
            lhs = LHSintegrator.create(s);
            obj.stiffness = lhs.compute();
        end

        function computeForces(obj)
            s.type     = 'Elastic';
            s.scale    = 'MACRO';
            s.dim      = obj.getFunDims();
            s.BC       = obj.boundaryConditions;
            s.mesh     = obj.mesh;
            s.material = obj.material;
            s.globalConnec = obj.mesh.connec;
            RHSint = RHSintegrator.create(s);
            rhs = RHSint.compute();
            % Perhaps move it inside RHSint?
            if strcmp(obj.solverType,'REDUCED')
                R = RHSint.computeReactions(obj.stiffness);
                obj.forces = rhs+R;
            else
                obj.forces = rhs;
            end
        end


        function u = computeDisplacement(obj)
            s.solverType = obj.solverType;
            s.solverMode = obj.solverMode;
            s.stiffness  = obj.stiffness;
            s.forces     = obj.forces;
            s.solver     = obj.solver;
            s.boundaryConditions = obj.boundaryConditions;
            s.BCApplier          = obj.BCApplier;
            s.uOld = zeros(size(obj.forces));
            pb = ProblemSolver(s);
            [u,L] = pb.solve();
            
            bc = obj.boundaryConditions;
            dofs = 1:obj.displacementFun.nDofs;
            free = setdiff(dofs, bc.dirichlet_dofs);
            cstr = bc.dirichlet_dofs;
            reactions = zeros(obj.displacementFun.nDofs, 1);
            reactions(bc.dirichlet_dofs) = L;
            reac_rshp = reshape(reactions,[obj.mesh.ndim,obj.mesh.nnodes])';


            a.mesh    = obj.mesh;
            a.fValues = reac_rshp;
            a.order   = 'P1';
            reacFun = LagrangianFunction(a);
            
            z.mesh    = obj.mesh;
            z.fValues = reshape(u,[obj.mesh.ndim,obj.mesh.nnodes])';
            z.order   = 'P1';
            uFeFun = LagrangianFunction(z);
            obj.uFun = uFeFun;
            uSplit = reshape(u,[obj.mesh.ndim,obj.mesh.nnodes])';
            obj.displacementFun.fValues = uSplit;
        end

        function computeStrain(obj)
            quad = Quadrature.create(obj.mesh, 2);
            xV = quad.posgp;
            obj.strainFun = SymGrad(obj.displacementFun);
%             strFun = strFun.obtainVoigtFormat();
            obj.strain = obj.strainFun.evaluate(xV);
        end

        function computeStress(obj)
            quad = Quadrature.create(obj.mesh, 2);
            xV = quad.posgp;
            obj.stressFun = DDP(obj.material, obj.strainFun);
            obj.stressFun.ndimf = obj.strainFun.ndimf;
            obj.stress = obj.stressFun.evaluate(xV);
        end

    end

end
