const Promise = require('bluebird');
const GhostAdminAPI = require('@tryghost/admin-api');

module.exports = async function (context, req) {

    try {

        const api = new GhostAdminAPI({
            url: process.env["GhostApiUrl"],
            key: process.env["GhostAdminApiKey"],
            version: "v3"
          });
    
        const allPosts = await api.posts.browse({limit: 'all'});
    
        const result = await Promise.mapSeries(allPosts, async (post) => {
            console.log('Deleting', post.id);
    
            // Call the API
            const result = await api.posts.delete({id: post.id});
            // Add a delay but return the original result
            return Promise.delay(50).return(result);
        });
    
        console.log('Deleted', result.length, 'members');
    
        const response = `Deleted ${result.length} members`;

        context.res = {
            body: response
        };
        
    } catch (error) {

        const response = `There was an error: ${require('util').inspect(error, false, null)}`;
        
        context.res = {
            body: response
        };
    }

}