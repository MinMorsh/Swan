classdef testVigdergauzMicroStructureWithStrain < testShowingError & testTopOptComputation
    
    properties (Access = private)
        designVariable
        unfittedMesh
        volume
        numericalVolume
    end
    
    properties (Access = protected)
        testName = 'test_VigergauzMicroStructureFromStrain';
        tol
    end
    
    methods (Access = public)
        
        function obj = testVigdergauzMicroStructureWithStrain()
            obj.init();
            obj.createUnfittedMesh();
            obj.computeFractionVolume();
        end
        
    end
    
    methods (Access = protected)
        
        function selectComputedVar(obj)
            obj.designVariable = obj.topOpt.designVariable;
        end
        
        function computeError(obj)
            v = obj.volume;
            nv = obj.numericalVolume;
            obj.error = abs(v - nv)/v;
        end
        
    end
    
    methods (Access = private)
        
        function init(obj)
            obj.tol = 2*1e-1;
            obj.volume = 0.75;
        end
        
        function createUnfittedMesh(obj)
            meshBackground = obj.topOpt.designVariable.mesh;
            s.backgroundMesh          = meshBackground.innerMeshOLD;
            s.boundaryMesh            = meshBackground.boxFaceMeshes;            
            cParams = SettingsMeshUnfitted(s);
            obj.unfittedMesh = UnfittedMesh(cParams);
            obj.unfittedMesh.compute(obj.designVariable.value);
        end
        
        function computeFractionVolume(obj)
            obj.numericalVolume = obj.unfittedMesh.computeMass();
        end
        
    end
    
    
end