classdef MeshComputer < handle

    properties (Access = public)
        p
        t
        e
        g
        remesh
        area
        ghold
    end

    methods (Access = public)

        function obj = MeshComputer()
            obj.create();
        end

    end

    methods (Access = private)

        function create(obj)
            load viga2x1.mat;
            prec = 1e6;
            obj.g = g;
            n = 40;
            [obj.p,obj.e,~] = poimesh(obj.g,2*n,n); %p1 = round(prec*p1)/prec; 
            %obj.t(4,:) = 1;
            
            load ConnectivitiesOriginal.mat;
            obj.t = t; 
            obj.ghold  = 0;
            nsteps = 1;
            obj.remesh  = 'longest';
        
            for i=1:2*nsteps
                [obj.p,obj.e,obj.t] = refinemesh(obj.g,obj.p,obj.e,obj.t,obj.remesh);            
            end
        
            obj.area = pdetrg(obj.p,obj.t);
        end
    end
end