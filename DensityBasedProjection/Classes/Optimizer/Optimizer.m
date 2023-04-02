classdef Optimizer < handle
    properties (Access = public)
        projectedField
    end

    properties (Access = private)
        mesh
        structure
        projectorParameters
        filterParameters
        displacement
        solverParameters
        iterations
        problemParameters
        E
        I
        D
    end

    methods (Access = public)
        function obj = Optimizer(cParams)
            obj.inputData(cParams);
        end

        function compute(obj)
            obj.optimize();
        end
    end
    methods (Access = private)
        function inputData(obj,cParams)

            obj.mesh = cParams.mesh;
            obj.structure = cParams.structure;
            obj.structure.elementType = 'Square';
            obj.projectorParameters = cParams.projector;
            obj.filterParameters= cParams.filterParameters;
            obj.solverParameters = cParams.solverParameters;
            obj.iterations = cParams.iterations;
            obj.E = cParams.E;
            obj.I = cParams.I;
            obj.D = cParams.D;
        end
        function optimize(obj)
            %Optimizer parameter
            iterbeta = 0;
            iter     = 0;
            itervol  = 0;
            finish = false;

            while (obj.solverParameters.costChange > 0.001) && (iter < 300) && (finish == false)
                %Actualización de variables al comienzo del bucle:
                iter     = iter     + 1;
                iterbeta = iterbeta + 1;
                itervol  = itervol  + 1;

                oldE = obj.E;
                oldI = obj.I;
                oldD = obj.D;
                %xold = obj.field(:);
                

                % Compute cost and displacement with the projected field
                obj.computeCost();
                % Calculate the cost derivated by the field
                obj.deriveCostRespectedField();
                % Compute volumen, derivate volumen, filter derivated volumen
                obj.computeVolumenValues();

                % Compute the solver
                obj.computeSolver(iter,oldE.designField.field);

                %Filter the new field
                obj.filterNewField();
                %Project the new filtered field
                obj.projectNewFilteredField();
                % Derivate the projected field respected the filteredField
                obj.deriveProjectedFieldRespectedFilteredField();
                %Plot results
                obj.plotResults(iter);
                %New optimizer parameters
                [iterbeta,itervol,finish,iter] = Optimizer.reconfigurateOptimizeParameters(obj,iterbeta,itervol,finish,iter);


            end

        end
    
        function computeCost(obj)
            %Get cost and displacement
            obj.E.designCost.computeCost();
            obj.I.designCost.computeCost();
            obj.D.designCost.computeCost();
        end

        function deriveCostRespectedField(obj)
            obj.E.designCost.deriveCost();
            obj.I.designCost.deriveCost();
            obj.D.designCost.deriveCost();
        end
        function computeSolver(obj,iter,xold)
            sC = [];
            c = CostAndConstraintArturo(sC);
            [f0val,df0dx,df0dx2] = c.computeCostValueAndGradient(obj.mesh.elementNumberX,obj.mesh.elementNumberY);
            [fval,dfdx,dfdx2] =  c.computeConstraintValueAndGradient(obj.cost.E,obj.cost.I,obj.cost.D,obj.volumen.value,obj.derivedCost.E,obj.derivedCost.I,obj.derivedCost.D,obj.volumen.derivated,obj.cost.initial);
            xval        = obj.field(:);
            [obj.solverParameters.xmma,~,obj.solverParameters.zmma,~,~,~,~,~,~,obj.solverParameters.low,obj.solverParameters.upp] = mmasub2Arturo(obj.solverParameters.numberRestriction,obj.solverParameters.variableNumber,iter,xval,obj.solverParameters.minDensity,obj.solverParameters.maxDensity,obj.solverParameters.xold1,obj.solverParameters.xold2, ...
                f0val,df0dx,df0dx2,fval,dfdx,dfdx2,obj.solverParameters.low,obj.solverParameters.upp,obj.solverParameters.a0,obj.solverParameters.mmaParameter.a,obj.solverParameters.mmaParameter.e,obj.solverParameters.mmaParameter.d);


            obj.solverParameters.xold2  = obj.solverParameters.xold1;
            obj.solverParameters.xold1  = xval;
            obj.field     = reshape(obj.solverParameters.xmma,obj.mesh.elementNumberY,obj.mesh.elementNumberX);
           obj.solverParameters.costChange  = norm(obj.solverParameters.xmma-xold,inf);

        end
        function computeVolumenValues(obj)
            s.mesh =obj.mesh;
            s.filterParameters = obj.filterParameters;
            s.projectedField = obj.projectedField;
            s.derivedProjectedField = obj.derivedProjectedField;
            s.volumen = obj.volumen;
            B = VolumenComputer(s);
            B.compute;
            obj.volumen = B.volumen;
        end
        function deriveProjectedFieldRespectedFilteredField(obj)
            obj.E.designField.deriveProjectedField();
            obj.I.designField.deriveProjectedField();
            obj.D.designField.deriveProjectedField();
        end
        function projectNewFilteredField(obj)
            s.beta = obj.projectorParameters.beta;
            s.eta = obj.projectorParameters.eta.E;
            s.filteredField =obj.filteredField;
            E = FieldProjector(s);
            E.compute();
            obj.projectedField.E = E.projectedField;

            s.beta =  obj.projectorParameters.beta;
            s.eta = obj.projectorParameters.eta.I;
            I = FieldProjector(s);
            I.compute();
            obj.projectedField.I = I.projectedField;

            s.beta =  obj.projectorParameters.beta;
            s.eta = obj.projectorParameters.eta.D;
            D = FieldProjector(s);
            D.compute();
            obj.projectedField.D = D.projectedField;

        end
        function filterNewField(obj)
            s.filterParameters = obj.filterParameters;
            s.field = obj.field;
            B = FilterComputer(s);
            B.compute();
            obj.filteredField = B.filteredField;
        end

        function plotResults(obj,iter)
%             subplot(3,1,1);
%             imagesc(-obj.projectedField.E); colormap(gray); caxis([-1 0]); axis off; axis equal; axis tight;
%             subplot(3,1,2);
%             imagesc(-obj.projectedField.I); colormap(gray); caxis([-1 0]); axis off; axis equal; axis tight;
%             subplot(3,1,3);
%             imagesc(-obj.projectedField.D); colormap(gray); caxis([-1 0]); axis off; axis equal; axis tight; pause(0.1)
            disp([' It.: ' sprintf('%4i',iter) ' Obj.: ' sprintf('%6.4f',obj.solverParameters.zmma) ...
                ' ui: '  sprintf('%12f', [obj.cost.E obj.cost.I obj.cost.D])...
                ' V: '   sprintf('%6.3f',sum(obj.projectedField.I(:))/(obj.mesh.elementNumberX*obj.mesh.elementNumberY)) ...
                ' ch.: ' sprintf('%6.3f', obj.solverParameters.costChange)])
        end
    end
    methods (Static)
        function [iterbeta,itervol,finish,iter] = reconfigurateOptimizeParameters(obj,iterbeta,itervol,finish,iter)
            if (obj.projectorParameters.beta < 32) && ((iterbeta >= 50) || (obj.solverParameters.costChange <= 0.01))
                obj.projectorParameters.beta     = 2*obj.projectorParameters.beta;
                iterbeta = 0;
                obj.solverParameters.costChange   = 1;
            end

            if (itervol >= 20 )
                itervol = 0;
                obj.volumen.volfracD = volumenFraction*sum(obj.projectedField.D(:))/sum(obj.projectedField.I(:));
            end
            if iter == obj.iterations
                finish = true;
            end
        end
    end
end